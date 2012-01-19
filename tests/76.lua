#!/usr/bin/env luvit

local String = require('string')

local sndr = require('../lib/hixie76').send
local recv = require('../lib/hixie76').receive

local hit = 0

function send_receive(orig, assert_message)
  local ws = {
    buffer = '',
    write = function (self, data, callback)
      recv(self, data)
    end,
    emit = function (self, event, data, ...)
      hit = hit + 1
      if orig ~= data then
        --p('PAYLOAD', data)
        print(assert_message)
        process.exit(1)
      end
      if hit == 10000 then
        p('DONE')
      end
    end,
  }
  sndr(ws, orig)
end

function send(orig)
  local ws = {
    buffer = '',
    write = function (self, data, callback)
      if callback then callback() end
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
  send_receive(('x'):rep(16384), i)
end

--[[
send_receive(('x'):rep(1), '1 x')
send_receive(('x'):rep(1024), '1024 x')
send_receive(('x'):rep(10240), '10240 x')
send_receive(('x'):rep(102400), '102400 x')]]--
--[[
-- send/receive string of all 65536 2-octet conmination
-- exception: 0xFF and 0x00 denote frames, so we exclude them
local s65536 = ''
for i = 1, 254 do for j = 1, 254 do
  --print(i, j)
  s65536 = s65536 .. String.char(i) .. String.char(j)
end end
send_receive(s65536, 'all chars')
]]--
