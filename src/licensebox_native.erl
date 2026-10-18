-module(licensebox_native).
-on_load(init/0).
-export([create/2,call/3,reply/3,close/1,derive/3,native/1,verify/4]).
init() -> Path=filename:join([filename:dirname(filename:dirname(code:which(?MODULE))),"priv","licensebox_nif"]),erlang:load_nif(Path,0).
create(_,_) -> erlang:nif_error(not_loaded).
call(_,_,_) -> erlang:nif_error(not_loaded).
reply(_,_,_) -> erlang:nif_error(not_loaded).
close(_) -> erlang:nif_error(not_loaded).
derive(_,_,_) -> erlang:nif_error(not_loaded).
native(_) -> erlang:nif_error(not_loaded).
verify(_,_,_,_) -> erlang:nif_error(not_loaded).
