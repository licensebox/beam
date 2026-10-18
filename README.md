# Licensebox beam SDK

MIT · 2026 Vijai Kumar · https://meshing.engineer

Native application licensing for Linux. Requires the public Licensebox C v0.3.0 shared library. Set `LICENSEBOX_LIB_DIR` (or `LICENSEBOX_LIBRARY` for runtime FFI bindings), and add that directory to `LD_LIBRARY_PATH` when linking native extensions. The host library retains installation keys, verifies leases, enforces native identity and stores usage locally. Other platforms and browser runtimes are unvalidated.

The client supports lease, require/module check, local status, sign-in, logout, modules, access requests, access links, and usage recording. Stateless derive/native binding and lease verification helpers are included. Close each client explicitly in a finally/ensure block. Trusted clock, machine binding, sign-in and cancellation hooks are callable platform integration points; never source identity from end users. Callbacks must not reenter or close their client. Callback exceptions become `callback_error` after the native call returns. Native-owned JSON is always freed.

`ci/setup.sh` installs dependencies on disposable Ubuntu 24.04 CI runners only. `ci/test.sh` compiles/tests the actual binding and package consumer. `ci/adapter.sh` runs the shared protocol adapter after testing/building. Run `python3 ../protocol/conformance/run.py --adapter "$PWD/ci/adapter.sh"` with the native environment configured. All test credentials and identities are synthetic.

Build the native core using `scripts/install-native.sh`, then set `LICENSEBOX_LIB_DIR="$PWD/.native/lib"` and `LD_LIBRARY_PATH="$LICENSEBOX_LIB_DIR${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"`. Supply only administrator-provided trusted Ed25519 public keys.

```elixir
{:ok, client} = Licensebox.start_link("my-app", %{"product-key" => trusted_public_key}, [],
  on_sign_in: fn url, code -> show_sign_in(url, code) end)
try do
  {:ok, _lease} = Licensebox.require_module(client, "core")
  # Protected work.
after
  Licensebox.close(client)
end
```

```erlang
{ok, Client} = licensebox:start_link(<<"my-app">>, #{<<"product-key">> => TrustedPublicKey}, #{},
    #{on_sign_in => fun(Url, Code) -> show_sign_in(Url, Code) end}),
try {ok, _Lease} = licensebox:require_module(Client, <<"core">>)
after licensebox:close(Client) end.
```

Both APIs return `{ok, Value}` / `{:ok, value}` or `{error, {Code, Detail}}` / `{:error, {code, detail}}`, with binary protocol codes. Erlang OTP 25+, Elixir 1.14+, a C compiler and Jiffy are required (`erlang-jiffy` on Ubuntu). `make` builds Erlang; `mix compile` builds Erlang plus Elixir. The client is an owning gen_server. Operations run on dirty I/O schedulers; callback functions execute in that owner's process and must not reenter it. The resource monitors its owner and wakes blocked callbacks if the owner exits. Explicit close is serialized, idempotent at the native-resource level, and terminates the client process. A stopped PID follows ordinary OTP `noproc` semantics.

Both expose `lease`, `require_module`, `status`, `sign_in`, `logout`, `modules`, `requests`, `request_access`, `access_link`, `record`, `close`, plus `derive_binding`, `native_binding`, `verify_lease`. Erlang `start_link/4` accepts option and hook maps with atom keys; Elixir accepts keyword lists or maps. JSON API values use binary-keyed maps. `ci/adapter.sh` exercises Erlang; `ci/adapter-elixir.sh` independently exercises the full Elixir API. Every `ci/test.sh` run performs the full Elixir protocol/TLS suites in addition to EUnit, ExUnit and package consumers.

The NIF uses the [official Erlang resource and monitor API](https://www.erlang.org/docs/25/man/erl_nif.html).

## Optional heartbeat checkpoints

Call `:licensebox.heartbeat(Client, <<"core">>) / Licensebox.heartbeat(client, "core")` with a module name to force a silent server check. It returns
`{"lease": ..., "online": true}` after contact, or `online: false` only while
an already verified offline lease remains valid. Heartbeat never activates,
transfers a seat or creates an installation key; sign in explicitly first.
Explicit refusals and removed module grants stop access immediately.

Background work remains opt-in. Schedule checkpoints in your application's own
runtime/event loop and stop protected work at the last verified lease's `expires`
time even if a renewal hangs. Use the signed `heartbeat.interval_seconds` when
present (otherwise a 300-second interval is a reasonable default); a failed
contact never extends the signed deadline. This SDK starts no heartbeat threads.
