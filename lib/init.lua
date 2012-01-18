local hixie76 = require('./hixie76').handshake
local hybi10 = require('./hybi10').handshake

local function handler(req, res, callback)

  -- request looks like WebSocket one?
  if   (req.headers.upgrade or ''):lower() ~= 'websocket'
    or not (',' .. (req.headers.connection or ''):lower() .. ','):match('[^%w]+upgrade[^%w]+')
  then
    res:set_code(400)
    res:finish()
    return
  end

  -- request has come from allowed origin?
  local origin = req.headers.origin
  -- TODO: 7/8 uses sec-websocket-origin?
  --[[if not verify_origin(origin, options.origins) then
    res:set_code(401)
    res:finish()
    return
  end]]--

  -- guess the protocol
  local location = origin and origin:sub(1, 5) == 'https' and 'wss' or 'ws'
  location = location .. '://' .. req.headers.host .. req.url
  -- determine protocol version
  local ver = req.headers['sec-websocket-version']
  local shaker = hixie76
  if ver == '7' or ver == '8' or ver == '13' then shaker = hybi10 end

  -- disable buffering
  res:nodelay(true)
  -- ??? timeout(0)?

  -- handshake, then register
  shaker(req, res, origin, location, callback)

end

-- module
return handler
