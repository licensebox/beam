-module(adapter).
-export([main/0]).
main()->
 io:setopts(standard_io,[binary,{encoding,utf8}]),
 R=jiffy:decode(read_all([]),[return_maps]),
 Result=run(R),Answer=case Result of {ok,V}->#{<<"ok">>=>true,<<"value">>=>V};{error,{Code,_}}->#{<<"ok">>=>false,<<"error">>=>Code} end,
 io:put_chars([jiffy:encode(Answer),"\n"]),halt().
read_all(A)->case io:get_chars(standard_io,"",4096) of eof->iolist_to_binary(lists:reverse(A));S->read_all([S|A]) end.
run(#{<<"op">>:=<<"derive">>}=R)->licensebox:derive_binding(maps:get(<<"product">>,R),maps:get(<<"source">>,R),maps:get(<<"raw_id">>,R));
run(#{<<"op">>:=<<"native">>}=R)->licensebox:native_binding(maps:get(<<"product">>,R));
run(#{<<"op">>:=<<"verify">>}=R)->licensebox:verify_lease(maps:get(<<"token">>,R),maps:get(<<"product">>,R),maps:get(<<"keys">>,R),maps:get(<<"now">>,R));
run(R)->
 BaseOpts=#{version=><<"conformance">>,server=>maps:get(<<"server">>,R),directory=>maps:get(<<"directory">>,R)},
 Opts=case maps:find(<<"ca_bundle">>,R) of {ok,CA}->BaseOpts#{ca_bundle=>CA};error->BaseOpts end,
 Hooks=#{clock=>fun()->maps:get(<<"now">>,R) end,machine_binding=>fun()->maps:get(<<"binding">>,R) end,on_sign_in=>fun(_,_)->ok end},
 {ok,C}=licensebox:start_link(maps:get(<<"product">>,R),maps:get(<<"keys">>,R),Opts,Hooks),
 try case maps:get(<<"op">>,R) of
 <<"lease">>->licensebox:lease(C);<<"status">>->licensebox:status(C);<<"sign_in">>->licensebox:sign_in(C,3);
 <<"require">>->licensebox:require_module(C,maps:get(<<"module">>,R,<<"core">>));
 <<"repeat">>->case licensebox:require_module(C,<<"core">>) of {ok,_}->licensebox:require_module(C,<<"core">>);E->E end;
 <<"logout">>->licensebox:logout(C);<<"modules">>->licensebox:modules(C);<<"requests">>->licensebox:requests(C);
 <<"request">>->licensebox:request_access(C,[<<"export">>],unicode:characters_to_binary("café – test"));
 <<"access-link">>->licensebox:access_link(C);
 <<"record">>->case licensebox:record(C,<<"export">>,true,0.125) of {ok,_}->licensebox:record(C,<<"export">>,false,0.025);E->E end
 end after licensebox:close(C) end.
