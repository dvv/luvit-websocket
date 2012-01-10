local get_digest = require('crypto').get_digest

local Math = require('math')

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

local function validate_secret(req_headers, nonce)
  local k1 = req_headers['sec-websocket-key1']
  local k2 = req_headers['sec-websocket-key2']
  if not k1 or not k2 then
    return false
  end
  local dg = get_digest('md5'):init()
  local _list_0 = { k1, k2 }
  for _index_0 = 1, #_list_0 do
    local k = _list_0[_index_0]
    local n = tonumber((gsub(k, '[^%d]', '')), 10)
    local spaces = #(gsub(k, '[^ ]', ''))
    if spaces == 0 or n % spaces ~= 0 then
      return false
    end
    n = n / spaces
    dg:update(char(rshift(n, 24) % 256, rshift(n, 16) % 256, rshift(n, 8) % 256, n % 256))
  end
  dg:update(nonce)
  local r = dg:final()
  dg:cleanup()
  return r
end

return function (self, origin, location, callback)

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
  local data = ''

  local ondata
  ondata = function (chunk)
    if chunk then
      data = data .. chunk
    end
    local buf = data
    if #buf == 0 then return end
    if byte(buf, 1) == 0 then
      for i = 2, #buf do
        if byte(buf, i) == 255 then
          local payload = sub(buf, 2, i - 1)
          data = sub(buf, i + 1)
          if #payload > 0 then
            self:emit('message', payload)
          end
          ondata()
          return
        end
      end
    else
      if byte(buf, 1) == 255 and byte(buf, 2) == 0 then
        self:emit('error')
      else
        self:emit('error', 1002, 'Broken framing')
      end
    end
  end

  self.req:once('data', function (chunk)
    data = data .. chunk
    if self.sec == false or #data >= 8 then
      if self.sec then
        local nonce = sub(data, 1, 8)
        data = sub(data, 9)
        local reply = validate_secret(self.req.headers, nonce)
        if not reply then
          self:do_reasoned_close()
          return
        end
        self.sec = nil
        self:on('data', ondata)
        self:write(reply)
        if callback then callback() end
      end
    end
  end)

  self.send = function (self, payload, callback)
    self:write('\000')
    self:write(payload)
    self:write('\255', callback)
  end

end
