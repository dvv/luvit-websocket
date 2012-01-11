local Crypto = require('crypto')
local rshift = require('bit').rshift

local sub, gsub, match, byte, char
do
  local _table_0 = require('string')
  sub, gsub, match, byte, char = _table_0.sub, _table_0.gsub, _table_0.match, _table_0.byte, _table_0.char
end

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
  for _, k in { k1, k2 } do
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
receiver = function (self, chunk)
  -- collect data chunks
  if chunk then self.buffer = self.buffer .. chunk end
  local buf = self.buffer
  -- wait for data
  if #buf == 0 then return end
  -- message starts with 0x00
  if byte(buf, 1) == 0 then
    -- and lasts
    for i = 2, #buf do
      -- until 0xFF
      if byte(buf, i) == 255 then
        -- extract payload
        local payload = sub(buf, 2, i - 1)
        -- consume data
        self.buffer = sub(buf, i + 1)
        -- emit event
        if #payload > 0 then
          self:emit('message', payload)
        end
        -- start over
        receiver(self)
        return
      end
    end
  -- close frame is sequence of 0xFF, 0x00
  else
    if byte(buf, 1) == 255 and byte(buf, 2) == 0 then
      self:emit('error')
    -- other sequences signify broken framimg
    else
      self:emit('error', 1002, 'Broken framing')
    end
  end
end

--
-- initialize the channel
--

local function handshake(self, origin, location, callback)

  -- ack connection
  self.sec = self.req.headers['sec-websocket-key1']
  local prefix = self.sec and 'Sec-' or ''
  local protocol = self.req.headers['sec-websocket-protocol']
  if protocol then
    protocol = (match(protocol, '[^,]*'))
  end
  self:write_head(101, {
    ['Upgrade'] = 'WebSocket',
    ['Connection'] = 'Upgrade',
    [prefix .. 'WebSocket-Origin'] = origin,
    [prefix .. 'WebSocket-Location'] = location,
    ['Sec-WebSocket-Protocol'] = protocol,
  })

  self.has_body = true

  -- verify connection
  local data = ''
  self.req:once('data', function (chunk)
    data = data .. chunk
    if self.sec == false or #data >= 8 then
      if self.sec then
        local nonce = sub(data, 1, 8)
        data = sub(data, 9)
        local reply = verify_secret(self.req.headers, nonce)
        -- close unless verified
        if not reply then
          self:emit('error')
          return
        end
        self.sec = nil
        -- setup receiver
        self.buffer = ''
        self.req:on('data', Utils.bind(self, receiver))
        -- register connection
        self:write(reply)
        if callback then callback() end
      end
    end
  end)

  -- setup sender
  self.send = sender

end

-- module
return {
  sender = sender,
  receiver = receiver,
  handshake = handshake,
}
