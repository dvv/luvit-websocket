--
-- http://tools.ietf.org/html/draft-ietf-hybi-thewebsocketprotocol-17
--

local Utils = require('utils')
local Crypto = require('crypto')

local Bit = require('bit')
local band, bor, bxor, rshift, lshift = Bit.band, Bit.bor, Bit.bxor, Bit.rshift, Bit.lshift

local String = require('string')
local sub, gsub, match, byte, char = String.sub, String.gsub, String.match, String.byte, String.char

local Math = require('math')

local atob = require('./util').atob

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

local function send_header(self, payload, mask)
  local len = #payload

  local l
  local masking = mask and 0x80 or 0x00

  -- compose header
  local h = { 0, 0, }
  h[1] = bor(0x80, 0x01)
  if len < 126 then
    h[2] = bor(len, masking)
    l = 2
  elseif len < 65536 then
    h[2] = bor(0x7E, masking)
    h[3] = band(rshift(len, 8), 0xFF)
    h[4] = band(len, 0xFF)
    l = 4
  else
    h[2] = bor(0x7F, masking)
    local len2 = len
    for i = 10, 3, -1 do
      h[i] = band(len2, 0xFF)
      len2 = rshift(len2, 8)
    end
    l = 10
  end

  -- put mask, if any
  if mask then
    local m = mask
    for i = 4, 1, -1 do
      h[l+i] = band(m, 0xFF)
      m = rshift(m, 8)
    end
  end

  -- write header
  local s = ''
  for _, b in ipairs(h) do s = s .. char(b) end
  self:write(s)
end

local function send_masked(self, payload, callback)
  local mask = Math.random(0, 0xFFFFFFFF)
  send_header(self, payload, mask)
  Codec.xor32(payload, #payload, mask)
  self:write(s, callback)
end

local function send_unmasked(self, payload, callback)
  send_header(self, payload)
  self:write(payload, callback)
end

--
-- extract complete message frames from incoming data
--

local receive
receive = function (req, chunk)

  -- collect data chunks
  if chunk then req.buffer = req.buffer .. chunk end
  -- wait for data
  if #req.buffer < 2 then return end
  local buf = req.buffer

  -- full frame should have 'finalized' flag set
  local first = band(byte(buf, 2), 0x7F)
  if band(byte(buf, 1), 0x80) ~= 0x80 then
    return
  end

  -- get frame type
  local opcode = band(byte(buf, 1), 0x0F)

  -- reject too lenghty close frames
  --[[ ?????
  if opcode == 8 and first >= 126 then
    req:emit('error', 1002, 'Wrong length for close frame')
    return
  end]]--

  local l = 0
  local length = 0
  -- is message masked?
  local masking = band(byte(buf, 2), 0x80) == 0x80

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
    payload = Codec.xor32s(payload, sub(buf, l - 3, l), length)
  end
  -- consume data
  req.buffer = sub(buf, l + length + 1)

  -- message frame?
  if opcode == 1 then
    -- emit 'message' event
    if #payload > 0 then
      req:emit('message', payload)
    end
    -- and start over
    receive(req)
  -- close frame
  elseif opcode == 8 then
    local status = nil
    local reason = nil
    -- contains 2-octet status
    if #payload >= 2 then
      status = bor(lshift(byte(payload, 1), 8), byte(payload, 2))
    end
    -- and textual reason
    if #payload > 2 then
      reason = sub(payload, 3)
    end
    -- report error. N.B. close is handled by error handler
    req:emit('close', status, reason)
  end

end

--
-- initialize the channel
--

local function handshake(req, res, origin, location, callback)

  -- ack connection
  local protocol = req.headers['sec-websocket-protocol']
  if protocol then protocol = (match(protocol, '[^,]*')) end
  res:writeHead(101, {
    ['Upgrade'] = 'WebSocket',
    ['Connection'] = 'Upgrade',
    ['Sec-WebSocket-Accept'] = atob(verify_secret(req.headers['sec-websocket-key'])),
    ['Sec-WebSocket-Protocol'] = protocol
  })
  res.has_body = true

  -- setup receiver
  req.buffer = ''
  req:on('data', Utils.bind(receive, req))
  -- setup sender
  res.send = send_unmasked

  -- register connection
  if callback then callback(req, res) end

end

-- module
return {
  send = send_unmasked,
  send_masked = send_masked,
  receive = receive,
  handshake = handshake,
}
