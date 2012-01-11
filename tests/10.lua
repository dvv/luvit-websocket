#!/usr/bin/env luvit

local String = require('string')

local sndr = require('../lib/hybi10').sender
local recv = require('../lib/hybi10').receiver

function send_receive(orig, assert_message)
  local ws = {
    buffer = '',
    write = function (self, data, callback)
      recv(self, data)
    end,
    emit = function (self, event, data, ...)
      if orig ~= data then
        --p('PAYLOAD', data)
        print(assert_message)
        process.exit(1)
      end
    end,
  }
  sndr(ws, orig)
end

send_receive(('x'):rep(1), '1 x')
send_receive(('x'):rep(1024), '1024 x')
-- send/receive string of all 65536 2-octet conmination
local s65536 = ''
for i = 0, 255 do for j = 0, 255 do
  --print(i, j)
  s65536 = s65536 .. String.char(i) .. String.char(j)
end end
--send_receive(s65536, 'all chars')
