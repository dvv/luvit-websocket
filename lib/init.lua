--
-- WebSocket protocol
--

local Table = require('table')
local Utils = require('utils')
local Timer = require('timer')

local hixie76 = require('./hixie76')
local hybi10 = require('./hybi10')

-- Connection
local Connection = { }
Utils.inherits(Connection, { })
--
-- create new connection
--

local default_options = {
  onopen = function (self)
  end,
  onclose = function (self)
  end,
  onerror = function (self, error)
  end,
  onmessage = function (self, message)
  end,
}

function Connection.new(response, options)
  self = Connection.new_obj()
  self.options = setmetatable(options or { }, { __index = default_options })
  self.readyState = 0
  self._send_queue = { }
  if response then
    self:_bind(response)
  end
  return self
end

--
-- send a message to remote end
--

function Connection.prototype:send(message)
  -- can only send to open connection
  if self.readyState ~= 1 then return false end
  -- put message in outgoing buffer
  Table.insert(self._send_queue, message)
  -- shedule flushing
  Timer.set_timeout(0, function () self:_flush() end)
  return true
end

--
-- orderly close the connection
--

function Connection.prototype:close(status, reason)
  -- can close only open connection
  if self.readyState == 1 then
    -- try to flush
    self:_flush()
    -- mark connection as closing
    self.readyState = 2
    -- upon sending close frame...
    -- FIXME: honor status and reason
    self:_packet('close', nil, function ()
      -- finish the response
      -- N.B. this will trigger res:on('closed') which will
      -- unbind response from connection,
      -- mark connection as in closed state
      -- and report application of connection closure
      self.res:finish()
    end)
    return true
  end
  return false
end

--
-- bind the response to this connection
--

function Connection.prototype:_bind(response)
  self.res = response

  -- any error in req closes the request
  response.req:once('error', function (err)
    response.req:close()
  end)

  -- unbind the client when response is closed
  response:once('closed', function ()
    self:_unbind()
  end)

  -- any error in res closes the response,
  -- causing client unbind
  response:on('error', function (err, reason)
    -- number errors are soft WebSocket protocol errors
    -- N.B. no error here means connection is closed orderly
    if type(err) == 'number' then
      self.options.onerror(self, err, reason)
    -- hard error
    else
      -- TODO: implement?
    end
    response:finish()
  end)

  -- handle incoming messages
  response:on('message', function (message)
    self.options.onmessage(self, message)
  end)

  -- augment response with helpers
  response.write_frame = write_frame
  -- send opening frame...
  self:_packet('open', nil, function ()
    -- and report connection is open
    self.readyState = 1
    self.options.onopen(self)
  end)

end

--
-- unbind the response
--

function Connection.prototype:_unbind()
  if self.res then
    self.readyState = 3
    self.options.onclose(self)
    self.res = nil
  end
end

--
-- flush outgoing buffer
--

function Connection.prototype:_flush()
  if not self.res or self._flushing then return end
  self._flushing = true
  local nmessages = #self._send_queue
  if nmessages > 0 then
    -- FIXME: should error occur, _send_queue is just missed...
    self:_packet('message', self._send_queue, function ()
      -- remove `nmessages` first messages
      for i = 1, nmessages do Table.remove(self._send_queue, 1) end
      self._flushing = nil
    end)
  end
end

--
-- send low-level frame.
-- implementations may override this to support custom encoding
--

function Connection.prototype:_packet(ptype, pdata, callback)
  if ptype == 'message' then
    self.res:send(Table.concat(pdata, ','), callback)
  elseif callback then
    callback()
  end
end

local function verify_origin(origin, origins)
  return true
end
--[[
  if origins.indexOf('*:*') isnt -1
        return true
    if not origin
        return false
    try
        parts = url.parse(origin)
        origins = [parts.host + ':' + parts.port,
                   parts.host + ':*',
                   '*:' + parts.port]
        if array_intersection(origins, origins).length > 0
            return true
    catch x
        null
    return false
]]--

--
-- WebSocket middleware
--

local function WebSocket_handler(options)

  -- defaults
  if not options then options = { } end

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
    res.ver = ver
    local shaker = hixie76
    if ver == '7' or ver == '8' or ver == '13' then
      shaker = hybi10
    end

    res:nodelay(true)
    --res.protocol = 'websocket'
    -- provide request accessor, to reduce the number of closures
    res.req = req

    -- handshake...
    shaker(res, origin, location, function ()
      -- and register connection
      local conn = Connection.new(res, options)
    end)

  end

end

-- module
return WebSocket_handler
