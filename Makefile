CC ?= cc
ERL_ROOT := $(shell erl +S 1 -noshell -eval 'io:format("~s",[code:root_dir()]),halt().')
all: priv/licensebox_nif.so ebin/licensebox.app
priv/licensebox_nif.so: c_src/licensebox_nif.c
	mkdir -p priv
	$(CC) -std=c11 -shared -fPIC -Wall -Wextra -I$(ERL_ROOT)/usr/include $< -L$(LICENSEBOX_LIB_DIR) -llicensebox -o $@
ebin/licensebox.app: src/*.erl src/licensebox.app.src
	mkdir -p ebin
	erlc -Werror -o ebin src/*.erl
	cp src/licensebox.app.src $@
package: all
	mkdir -p build/package/licensebox-0.2.0
	cp -r c_src src lib priv ebin Makefile mix.exs LICENSE README.md build/package/licensebox-0.2.0/
	tar -czf build/licensebox-beam-0.2.0.tar.gz -C build/package licensebox-0.2.0
.PHONY: all package
