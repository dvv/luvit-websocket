--
-- WebSocket protocol
--

local hixie76 = require('./hixie76').handshake
local hybi10 = require('./hybi10').handshake

--
-- verify whether origin `exists` in `origins`
--

-- TODO: implement!
local function verify_origin(origin, origins)
  return true
end

--
-- WebSocket middleware
--

local function WebSocket_handler(options)

  -- defaults
  if not options then options = { } end
  assert(type(options.new) == 'function', 'Must provide connection constructor in options.new')

  -- handler
  return function (req, res, nxt)

    -- turn chunking mode off
    res.auto_chunked = false

    -- request sanity check
    if (req.headers.upgrade or ''):lower() ~= 'websocket' then
      return res:send(400, 'Bad Request')
    end
    if not (',' .. (req.headers.connection or ''):lower() .. ','):match('[^%w]+upgrade[^%w]+') then
      return res:send(400, 'Bad Request')
    end
    local origin = req.headers.origin
    if not verify_origin(origin, options.origins) then
      return res:send(401, 'Unauthorized')
    end

    -- guess the protocol
    local location = origin and origin:sub(1, 5) == 'https' and 'wss' or 'ws'
    location = location .. '://' .. req.headers.host .. req.url
    -- determine protocol version
    local ver = req.headers['sec-websocket-version']
    local shaker = hixie76
    if ver == '7' or ver == '8' or ver == '13' then
      shaker = hybi10
    end

    -- disable buffering
    res:nodelay(true)
    -- provide request accessor, to reduce the number of closures
    res.req = req

    -- handshake...
    shaker(res, origin, location, function ()
      -- and register connection
      local conn = options.new(res, options)
    end)

  end

end

-- module
return WebSocket_handler
