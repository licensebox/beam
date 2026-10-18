#!/usr/bin/env bash
set -euo pipefail
sudo apt-get update
sudo apt-get install -y erlang-base erlang-dev erlang-eunit erlang-jiffy erlang-xmerl elixir build-essential
