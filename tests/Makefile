unit:
	echo Unit: hybi10
	./10.lua
	echo Unit: hixie76
	./76.lua

connect:
	./node_modules/.bin/wscat --connect ws://localhost:8080/ws

speed:
	time ./10.lua

.PHONY: unit connect speed
.SILENT:
