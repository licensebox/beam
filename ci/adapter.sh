#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
exec erl +S 2:2 +SDio 2 +SDcpu 1 -noshell -pa ebin -s adapter main
