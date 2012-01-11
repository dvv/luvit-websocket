local Utils = require('utils')
local Crypto = require('crypto')

local band, bor, bxor, rshift, lshift
do
  local _table_0 = require('bit')
  band, bor, bxor, rshift, lshift = _table_0.band, _table_0.bor, _table_0.bxor, _table_0.rshift, _table_0.lshift
end

local sub, gsub, match, byte, char
do
  local _table_0 = require('string')
  sub, gsub, match, byte, char = _table_0.sub, _table_0.gsub, _table_0.match, _table_0.byte, _table_0.char
end

local base64_table = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local function base64(data)
  return ((gsub(data, '.', function(x)
    local r, b = '', byte(x)
    for i = 8, 1, -1 do
      r = r .. (b % 2 ^ i - b % 2 ^ (i - 1) > 0 and '1' or '0')
    end
    return r
  end) .. '0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
    if #x < 6 then
      return ''
    end
    local c = 0
    for i = 1, 6 do
      c = c + (sub(x, i, i) == '1' and 2 ^ (6 - i) or 0)
    end
    return sub(base64_table, c + 1, c + 1)
  end) .. ({
    '',
    '==',
    '='
  })[#data % 3 + 1])
end

local Table = require('table')
local push = Table.insert

local function verify_secret(key)
  local data = (match(key, '(%S+)')) .. '258EAFA5-E914-47DA-95CA-C5AB0DC85B11'
  return Crypto.sha1(data, true)
end

-- Lua has no mutable string. Workarounds are slow too.
-- Let's employ C power.
local Codec = require('../build/hybi10.luvit')

local function sender(self, payload, callback)
  local plen = #payload
  -- compose the out buffer
  local str = (' '):rep(plen < 126 and 6 or (plen < 65536 and 8 or 14)) .. payload
  -- encode the payload
  Codec.encode(str, plen)
  -- put data on wire
  self:write(str, callback)
end

local receiver
receiver = function (self, chunk)

  if chunk then self.buffer = self.buffer .. chunk end
  if #self.buffer < 2 then return end
  local buf = self.buffer

  local status = nil
  local reason = nil

  local first = band(byte(buf, 2), 0x7F)
  if band(byte(buf, 1), 0x80) ~= 0x80 then
    self:emit('error', 1002, 'Fin flag not set')
    return 
  end

  local opcode = band(byte(buf, 1), 0x0F)
  if opcode ~= 1 and opcode ~= 8 then
    self:emit('error', 1002, 'not a text nor close frame')
    return 
  end

  if opcode == 8 and first >= 126 then
    self:emit('error', 1002, 'wrong length for close frame')
    return 
  end

  local l = 0
  local length = 0
  local key = { }
  local masking = band(byte(buf, 2), 0x80) ~= 0
  if first < 126 then
    length = first
    l = 2
  else
    if first == 126 then
      if #buf < 4 then
        return 
      end
      length = bor(lshift(byte(buf, 3), 8), byte(buf, 4))
      l = 4
    else
      if first == 127 then
        if #buf < 10 then
          return 
        end
        length = 0
        for i = 3, 10 do
          length = bor(length, lshift(byte(buf, i), (10 - i) * 8))
        end
        l = 10
      end
    end
  end
  if masking then
    if #buf < l + 4 then
      return 
    end
    key[1] = byte(buf, l + 1)
    key[2] = byte(buf, l + 2)
    key[3] = byte(buf, l + 3)
    key[4] = byte(buf, l + 4)
    l = l + 4
  end
  if #buf < l + length then
    return 
  end

  local payload = sub(buf, l + 1, l + length)
  if masking then
    Codec.mask(payload, sub(buf, l - 3, l), length)
  end
  self.buffer = sub(buf, l + length + 1)

  if opcode == 1 then
    if #payload > 0 then
      self:emit('message', payload)
    end
    receiver(self)
    return
  else
    if opcode == 8 then
      if #payload >= 2 then
        status = bor(lshift(byte(payload, 1), 8), byte(payload, 2))
      end
      if #payload > 2 then
        reason = sub(payload, 3)
      end
      self:emit('error', status, reason)
    end
  end
end

local function handshake(self, origin, location, callback)

  -- ack connection
  local protocol = self.req.headers['sec-websocket-protocol']
  if protocol then
    protocol = (match(protocol, '[^,]*'))
  end
  self:write_head(101, {
    ['Upgrade'] = 'WebSocket',
    ['Connection'] = 'Upgrade',
    ['Sec-WebSocket-Accept'] = base64(verify_secret(self.req.headers['sec-websocket-key'])),
    ['Sec-WebSocket-Protocol'] = protocol
  })

  self.has_body = true

  -- setup receiver
  self.buffer = ''
  self.req:on('data', Utils.bind(self, receiver))
  -- setup sender
  self.send = sender

  -- register connection
  if callback then callback() end

end

-- module
return {
  sender = sender,
  receiver = receiver,
  handshake = handshake,
}
