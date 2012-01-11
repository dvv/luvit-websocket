CFLAGS   := $(shell luvit-config --cflags)

all:
	gcc -shared -g $(CFLAGS) -o lib/hybi10.luvit lib/hybi10.c
