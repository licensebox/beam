#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export ERL_FLAGS='+S 2:2 +SDio 2 +SDcpu 1'
make
erlc -Werror -o ebin tests/adapter.erl tests/binding_test.erl
erl -noshell -pa ebin -eval 'case eunit:test(binding_test,[verbose]) of ok->halt(0);_->halt(1) end.'
mix compile --warnings-as-errors
mix run tests/binding_test.exs
make package
mkdir -p build/consumer
tar -xzf build/licensebox-beam-0.1.0.tar.gz -C build/consumer
(cd build/consumer/licensebox-0.1.0 && make && erl -noshell -pa ebin -eval '{ok,_}=licensebox:native_binding(<<"demo">>),halt().' && mix compile --warnings-as-errors && mix run -e '{:ok, _} = Licensebox.native_binding("demo")')
# The reusable workflow exercises Erlang through adapter.sh. Exercise the full
# independently written Elixir adapter here as part of every package build.
protocol_dir=${LICENSEBOX_PROTOCOL_DIR:-../protocol}
test -f "$protocol_dir/conformance/run.py"
python3 "$protocol_dir/conformance/run.py" --adapter "$PWD/ci/adapter-elixir.sh"
python3 "$protocol_dir/conformance/tls_transport.py" --adapter "$PWD/ci/adapter-elixir.sh"

python3 "$protocol_dir/conformance/heartbeat.py" --adapter "$PWD/ci/adapter-elixir.sh"
