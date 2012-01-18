local Utils = require('utils')
local Crypto = require('crypto')
local rshift = require('bit').rshift

local String = require('string')
local sub, gsub, match, byte, char = String.sub, String.gsub, String.match, String.byte, String.char

--
-- verify connection secret
--

local function verify_secret(req_headers, nonce)
  local k1 = req_headers['sec-websocket-key1']
  local k2 = req_headers['sec-websocket-key2']
  if not k1 or not k2 then
    return false
  end
  local data = ''
  for _, k in ipairs({ k1, k2 }) do
    local n = tonumber((gsub(k, '[^%d]', '')), 10)
    local spaces = #(gsub(k, '[^ ]', ''))
    if spaces == 0 or n % spaces ~= 0 then
      return false
    end
    n = n / spaces
    data = data .. char(rshift(n, 24) % 256, rshift(n, 16) % 256, rshift(n, 8) % 256, n % 256)
  end
  data = data .. nonce
  return Crypto.md5(data, true)
end

--
-- send payload
--

local function sender(self, payload, callback)
  self:write('\000')
  self:write(payload)
  self:write('\255', callback)
end

--
-- extract complete message frames from incoming data
--

local receiver
receiver = function (req, chunk)
  -- collect data chunks
  if chunk then req.buffer = req.buffer .. chunk end
  local buf = req.buffer
  -- wait for data
  if #buf == 0 then return end
  -- message starts with 0x00
  if byte(buf, 1) == 0x00 then
    -- and lasts
    for i = 2, #buf do
      -- until 0xFF
      if byte(buf, i) == 0xFF then
        -- extract payload
        local payload = sub(buf, 2, i - 1)
        -- consume data
        req.buffer = sub(buf, i + 1)
        -- emit event
        if #payload > 0 then
          req:emit('message', payload)
        end
        -- start over
        receiver(req)
        return
      end
    end
  -- close frame is sequence of 0xFF, 0x00
  else
    if byte(buf, 1) == 0xFF and byte(buf, 2) == 0x00 then
      req:emit('error', 1000)
    -- other sequences signify broken framimg
    else
      req:emit('error', 1002, 'Broken framing')
    end
  end
end

--
-- initialize the channel
--

local function handshake(req, res, origin, location, callback)

  -- ack connection
  res.sec = req.headers['sec-websocket-key1']
  local prefix = res.sec and 'Sec-' or ''
  local protocol = req.headers['sec-websocket-protocol']
  if protocol then
    protocol = (match(protocol, '[^,]*'))
  end
  res:write_head(101, {
    ['Upgrade'] = 'WebSocket',
    ['Connection'] = 'Upgrade',
    [prefix .. 'WebSocket-Origin'] = origin,
    [prefix .. 'WebSocket-Location'] = location,
    ['Sec-WebSocket-Protocol'] = protocol,
  })

  res.has_body = true

  -- verify connection
  local data = ''
  req:once('data', function (chunk)
    data = data .. chunk
    if res.sec == false or #data >= 8 then
      if res.sec then
        local nonce = sub(data, 1, 8)
        data = sub(data, 9)
        local reply = verify_secret(req.headers, nonce)
        -- close unless verified
        if not reply then
          res:emit('error')
          return
        end
        res.sec = nil
        -- setup receiver
        req.buffer = ''
        req:on('data', Utils.bind(req, receiver))
        -- consume initial data
        req:emit('data', data)
        -- register connection
        res:write(reply)
        if callback then callback(req, res) end
      end
    end
  end)

  -- setup sender
  res.send = sender

end

-- module
return {
  sender = sender,
  receiver = receiver,
  handshake = handshake,
}
