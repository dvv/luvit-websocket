CFLAGS   := $(shell luvit-config --cflags)

all: build/hybi10.luvit

build/hybi10.luvit: src/hybi10.c
	mkdir -p build
	gcc -shared -g $(CFLAGS) -o $@ $^
