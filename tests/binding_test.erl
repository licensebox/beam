-module(binding_test).
-include_lib("eunit/include/eunit.hrl").
identity_test()->?assertMatch({ok,<<"m1:",_/binary>>},licensebox:derive_binding(<<"demo">>,<<"linux-machine-id">>,<<"12345678123456789abc1234567890ab",0>>)).
verify_test()->?assertMatch({error,{<<"malformed">>,_}},licensebox:verify_lease(<<"bad">>,<<"demo">>,#{},0)).
callback_test()->
 Dir=filename:join("/tmp","licensebox-beam-test-"++integer_to_list(erlang:unique_integer([positive]))),
 Key= <<"A6EHv_POEL4dcN0Y50vAmWfk1jCbpQ1fHdyGZBJVMbg">>,
 {ok,C}=licensebox:start_link(<<"demo">>,#{<<"test-key">>=>Key},#{directory=>list_to_binary(Dir)},#{machine_binding=>fun()->error(synthetic_failure)end}),
 try ?assertMatch({error,{<<"callback_error">>,_}},licensebox:sign_in(C,0.1)) after licensebox:close(C),file:del_dir_r(Dir) end.
owner_down_test()->
 Parent=self(),Dir=filename:join("/tmp","licensebox-beam-owner-"++integer_to_list(erlang:unique_integer([positive]))),
 Options=jiffy:encode(#{<<"product">>=><<"demo">>,<<"keys">>=>#{<<"test-key">>=><<"A6EHv_POEL4dcN0Y50vAmWfk1jCbpQ1fHdyGZBJVMbg">>},<<"directory">>=>list_to_binary(Dir)}),
 spawn(fun()->{ok,R}=licensebox_native:create(Options,4),Parent!{resource,R},receive {licensebox_callback,_,_,_,_}->Parent!callback_started end end),
 R=receive {resource,Resource}->Resource after 2000->error(resource_timeout) end,
 spawn(fun()->Parent!{result,licensebox_native:call(R,<<"sign_in">>,<<"{\"timeout\":0.1}">>)} end),
 receive callback_started->ok after 2000->error(callback_timeout) end,
 receive {result,Result}->?assertMatch({error,{<<"callback_error">>,_}},Result) after 2000->error(owner_down_timeout) end,
 licensebox_native:close(R),file:del_dir_r(Dir).
