local hixie76 = require('./hixie76')
local hybi10 = require('./hybi10')

local function handler(req, res, callback)

  -- request looks like WebSocket one?
  if   (req.headers.upgrade or ''):lower() ~= 'websocket'
    or not (',' .. (req.headers.connection or ''):lower() .. ','):match('[^%w]+upgrade[^%w]+')
  then
    res:setCode(400)
    res:finish()
    return
  end

  -- request has come from allowed origin?
  local origin = req.headers.origin
  -- TODO: 7/8 uses sec-websocket-origin?
  --[[if not verify_origin(origin, options.origins) then
    res:setCode(401)
    res:finish()
    return
  end]]--

  -- guess the protocol
  local location = origin and origin:sub(1, 5) == 'https' and 'wss' or 'ws'
  location = location .. '://' .. req.headers.host .. req.url
  -- determine protocol version
  local ver = req.headers['sec-websocket-version']
  local draft = hixie76
  if ver == '7' or ver == '8' or ver == '13' then draft = hybi10 end

  -- disable buffering
  res.socket._handle:nodelay(true)
  -- ??? timeout(0)?

  -- handshake, then register
  draft.handshake(req, res, origin, location, callback)

end

-- module
return {
  handler = handler,
  hixie76 = hixie76,
  hybi10 = hybi10,
}
