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
      --p('RECV', data, orig, #data, #orig)
      if orig ~= data then
        print('FAILED: ' .. assert_message)
        process.exit(1)
      end
    end,
  }
  sndr(ws, orig)
end

function send(orig)
  local ws = {
    buffer = '',
    write = function (self, data, callback)
      callback()
    end,
  }
  sndr(ws, orig, function ()
    --p('DONE', #orig)
  end)
end

--[[
for i = 1, 16 do
  local n = 2 ^ i
  send(('x'):rep(n), n .. ' x')
end
]]--
for i = 1, 10000 do
  --send(('x'):rep(2), i)
  --send(('x'):rep(32768), i)
  send_receive(('x'):rep(163840), i)
  --send_receive(('x'):rep(163840), i)
end

--[[
send_receive(('x'):rep(1), '1 x')
send_receive(('x'):rep(1024), '1024 x')
send_receive(('x'):rep(10240), '10240 x')
send_receive(('x'):rep(102400), '102400 x')]]--
--[[
-- send/receive string of all 65536 2-octet conmination
local s65536 = ''
for i = 0, 255 do for j = 0, 255 do
  --print(i, j)
  s65536 = s65536 .. String.char(i) .. String.char(j)
end end
send_receive(s65536, 'all chars')
]]--
