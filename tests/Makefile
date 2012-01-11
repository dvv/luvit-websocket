unit:
	echo Unit: hybi10
	./10.lua
	echo Unit: hixie76
	./76.lua

connect:
	./node_modules/.bin/wscat --connect ws://localhost:8080/ws

speed:
	echo -n >speed
	echo Speed: hybi10 >>speed
	time ./10.lua >>speed
	echo Speed: hixie76 >>speed
	time ./76.lua >>speed

.PHONY: unit connect speed
.SILENT:
