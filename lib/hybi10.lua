local Utils = require('utils')
local Crypto = require('crypto')

local Bit = require('bit')
local band, bor, bxor, rshift, lshift = Bit.band, Bit.bor, Bit.bxor, Bit.rshift, Bit.lshift

local String = require('string')
local sub, gsub, match, byte, char = String.sub, String.gsub, String.match, String.byte, String.char

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

--
-- verify connection secret
--

local function verify_secret(key)
  local data = (match(key, '(%S+)')) .. '258EAFA5-E914-47DA-95CA-C5AB0DC85B11'
  return Crypto.sha1(data, true)
end

-- Lua has no mutable string. Workarounds are slow too.
-- Let's employ C power.
local Codec = require('../build/hybi10.luvit')

--
-- send payload
--

local function sender(self, payload, callback)
  local plen = #payload
  -- compose the out buffer
  local str = (' '):rep(plen < 126 and 6 or (plen < 65536 and 8 or 14)) .. payload
  -- encode the payload
  -- TODO: knowing plen we can create prelude separately from payload
  -- hence avoid concat
  Codec.encode(str, plen)
  -- put data on wire
  self:write(str, callback)
end

--
-- extract complete message frames from incoming data
--

local receiver
receiver = function (self, chunk)

  -- collect data chunks
  if chunk then self.buffer = self.buffer .. chunk end
  -- wait for data
  if #self.buffer < 2 then return end
  local buf = self.buffer

  local status = nil
  local reason = nil

  -- frame should have 'finalized' flag set
  -- TODO: fragments!
  local first = band(byte(buf, 2), 0x7F)
  if band(byte(buf, 1), 0x80) ~= 0x80 then
    self:emit('error', 1002, 'Fin flag not set')
    return 
  end

  -- get frame type
  -- N.B. we support only text and close frames
  local opcode = band(byte(buf, 1), 0x0F)
  if opcode ~= 1 and opcode ~= 8 then
    self:emit('error', 1002, 'not a text nor close frame')
    return 
  end

  -- reject too lenghty close frames
  if opcode == 8 and first >= 126 then
    self:emit('error', 1002, 'wrong length for close frame')
    return 
  end

  local l = 0
  local length = 0
  -- is message masked?
  local masking = band(byte(buf, 2), 0x80) ~= 0

  -- get the length of payload.
  -- wait for additional data chunks if amount of data is insufficient
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

  -- message masked?
  if masking then
    -- frame should contain 4-octet mask
    if #buf < l + 4 then
      return 
    end
    l = l + 4
  end
  -- frame should be completely available
  if #buf < l + length then
    return 
  end

  -- extract payload
  -- TODO: buffers can save much time here
  local payload = sub(buf, l + 1, l + length)
  -- unmask if masked
  if masking then
    payload = Codec.mask(payload, sub(buf, l - 3, l), length)
  end
  -- consume data
  self.buffer = sub(buf, l + length + 1)

  -- message frame?
  if opcode == 1 then
    -- emit 'message' event
    if #payload > 0 then
      self:emit('message', payload)
    end
    -- and start over
    receiver(self)
  -- close frame
  elseif opcode == 8 then
    -- contains 2-octet status
    if #payload >= 2 then
      status = bor(lshift(byte(payload, 1), 8), byte(payload, 2))
    end
    -- and textual reason
    if #payload > 2 then
      reason = sub(payload, 3)
    end
    -- report error. N.B. close is handled by error handler
    self:emit('error', status, reason)
  end

end

--
-- initialize the channel
--

local function handshake(self, origin, location, callback)

  -- ack connection
  local protocol = self.req.headers['sec-websocket-protocol']
  if protocol then protocol = (match(protocol, '[^,]*')) end
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
