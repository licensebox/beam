#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export ERL_FLAGS='+S 2:2 +SDio 2 +SDcpu 1'
exec elixir -pa _build/dev/lib/licensebox/ebin tests/adapter.exs
