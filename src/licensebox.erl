-module(licensebox).
-behaviour(gen_server).
-export([start_link/2,start_link/4,close/1,lease/1,require_module/2,status/1,sign_in/1,sign_in/2,logout/1,modules/1,requests/1,request_access/3,access_link/1,record/4,derive_binding/3,native_binding/1,verify_lease/4]).
-export([init/1,handle_call/3,handle_cast/2,handle_info/2,terminate/2,code_change/3]).
start_link(Product,Keys)->start_link(Product,Keys,#{},#{}).
%% Hooks are typed trusted funs. Identity is never read from the options map.
start_link(Product,Keys,Options,Hooks)->gen_server:start_link(?MODULE,{Product,Keys,Options,Hooks},[]).
arg(B) when is_binary(B)->case binary:match(B,<<0>>) of nomatch->B;_->error(invalid_argument) end;
arg(_)->error(invalid_argument).
keys(Keys)->maps:from_list([{arg(K),arg(V)}||{K,V}<-maps:to_list(Keys)]).
init({Product,Keys,Options,Hooks})->
 try
  maps:foreach(fun(Name,F)->Arity=case Name of on_sign_in->2;clock->0;machine_binding->0;cancelled->0 end,true=is_function(F,Arity) end,Hooks),
  Base=#{<<"product">>=>arg(Product),<<"keys">>=>keys(Keys),<<"version">>=>arg(maps:get(version,Options,<<>>))},
  Opts=lists:foldl(fun(K,M)->case maps:find(K,Options) of {ok,V}->M#{atom_to_binary(K,utf8)=>arg(V)};error->M end end,Base,[server,directory,ca_bundle]),
  Mask=lists:foldl(fun({K,N},A)->case maps:is_key(K,Hooks) of true->A bor N;false->A end end,0,[{on_sign_in,1},{clock,2},{machine_binding,4},{cancelled,8}]),
  case licensebox_native:create(jiffy:encode(Opts),Mask) of {ok,Resource}->{ok,#{resource=>Resource,hooks=>Hooks,pending=>none,queue=>queue:new()}};{error,E}->{stop,E} end
 catch _:Reason->{stop,{invalid_argument,Reason}} end.
call(Pid,_Op,_Args) when Pid=:=self()->{error,{<<"invalid_argument">>,<<"callbacks must not reenter client">>}};
call(Pid,Op,Args)->gen_server:call(Pid,{operation,Op,Args},infinity).
close(Pid) when Pid=:=self()->{error,{<<"invalid_argument">>,<<"callbacks must not close client">>}};
close(Pid)->gen_server:call(Pid,close,infinity).
lease(P)->call(P,<<"lease">>,#{}).
require_module(P,M)->call(P,<<"require">>,#{<<"module">>=>arg(M)}).
status(P)->call(P,<<"status">>,#{}).
sign_in(P)->sign_in(P,0).
sign_in(P,T) when is_number(T)->call(P,<<"sign_in">>,#{<<"timeout">>=>T}).
logout(P)->call(P,<<"logout">>,#{}).
modules(P)->call(P,<<"modules">>,#{}).
requests(P)->call(P,<<"requests">>,#{}).
request_access(P,Modules,Note)->call(P,<<"request">>,#{<<"modules">>=>[arg(M)||M<-Modules],<<"note">>=>arg(Note)}).
access_link(P)->call(P,<<"access-link">>,#{}).
record(P,Command,Success,Elapsed) when is_boolean(Success),is_number(Elapsed),Elapsed>=0->call(P,<<"record">>,#{<<"command">>=>arg(Command),<<"success">>=>Success,<<"elapsed">>=>Elapsed}).
trim(B) when byte_size(B)>0->case binary:last(B) of 0->trim(binary:part(B,0,byte_size(B)-1));_->B end;
trim(B)->B.
derive_binding(P,S,R)->licensebox_native:derive(arg(P),arg(S),trim(R)).
native_binding(P)->licensebox_native:native(arg(P)).
verify_lease(T,P,K,N)->decode(licensebox_native:verify(arg(T),arg(P),jiffy:encode(keys(K)),N)).
decode({ok,Json})->{ok,jiffy:decode(Json,[return_maps])};decode(Error)->Error.
start_operation({operation,Op,Args},From,S)->
 Owner=self(),Ref=make_ref(),Resource=maps:get(resource,S),
 {_,Monitor}=spawn_monitor(fun()->Owner!{licensebox_result,Ref,licensebox_native:call(Resource,Op,jiffy:encode(Args))} end),
 S#{pending=>{Ref,Monitor,From}}.
handle_call(Request,From,#{pending:=none}=S) when element(1,Request)=:=operation->{noreply,start_operation(Request,From,S)};
handle_call(close,_From,#{pending:=none,resource:=R}=S)->licensebox_native:close(R),{stop,normal,ok,S};
handle_call(Request,From,S)->{noreply,S#{queue=>queue:in({Request,From},maps:get(queue,S))}}.
handle_cast(_,S)->{noreply,S}.
handle_info({licensebox_callback,R,Seq,Kind,Args},#{resource:=R,hooks:=Hooks}=S)->
 Reply=try {ok,apply(maps:get(Kind,Hooks),Args)} catch _:_->{error,callback_error} end,
 licensebox_native:reply(R,Seq,Reply),{noreply,S};
handle_info({licensebox_result,Ref,Result},#{pending:={Ref,Monitor,From}}=S)->
 erlang:demonitor(Monitor,[flush]),gen_server:reply(From,decode(Result)),next(S#{pending=>none});
handle_info({'DOWN',Monitor,process,_,Reason},#{pending:={_,Monitor,From}}=S)->
 gen_server:reply(From,{error,{<<"callback_error">>,iolist_to_binary(io_lib:format("~p",[Reason]))}}),next(S#{pending=>none});
handle_info(_,S)->{noreply,S}.
next(#{queue:=Q}=S)->case queue:out(Q) of
 {empty,_}->{noreply,S};
 {{value,{close,From}},Rest}->licensebox_native:close(maps:get(resource,S)),gen_server:reply(From,ok),{stop,normal,S#{queue=>Rest}};
 {{value,{Request,From}},Rest}->{noreply,start_operation(Request,From,S#{queue=>Rest})} end.
terminate(_,S)->licensebox_native:close(maps:get(resource,S)),ok.
code_change(_,S,_)->{ok,S}.
