--
-- Connection
--

local Table = require('table')
local Utils = require('utils')
local Timer = require('timer')

local Connection = {
  CONNECTING = 0,
  OPEN = 1,
  CLOSING = 2,
  CLOSED = 3,
}

Utils.inherits(Connection, { })

local default_options = {
  onopen = function (self) end,
  onclose = function (self) end,
  onerror = function (self, error) end,
  onmessage = function (self, message) end,
  disconnect_delay = 5000,
}

--
-- connections table
--

local connections = { }
-- TODO: strip
_G.c = connections
_G.cl = function (...)
  connections['1']:close(...)
end
_G.s = function (...)
  for _, co in pairs(connections) do
    co:send(...)
  end
end
local nconn = 0

--
-- create new connection
--

function Connection.new(response, options)
  self = Connection.new_obj()
  -- TODO: add entropy
  nconn = nconn + 1
  self.id = tostring(nconn)
  self.options = setmetatable(options or { }, { __index = default_options })
  self.readyState = Connection.CONNECTING
  connections[self.id] = self
  self._send_queue = { }
  if response then
    self:_bind(response)
  end
  return self
end

--
-- get existing connection by id
--

function Connection.get(id)
  return connections[id]
end

--
-- send a message to remote end
--

function Connection.prototype:send(message)
  -- can only send to open connection
  if self.readyState ~= Connection.OPEN then return false end
  self:_packet('message', message)
  return true
end

--
-- orderly close the connection
--

function Connection.prototype:close(code, reason)
  -- can close only open[ing] connection
  if self.readyState < Connection.CLOSING then
    -- try to flush
    self:_flush()
    -- mark connection as closing
    self.readyState = Connection.CLOSING
    -- upon sending close frame...
    self:_packet('close', { code, reason }, function ()
      -- finish the response
      -- N.B. this will trigger res:on('closed') which will
      -- unbind response from connection,
      -- mark connection as in closed state
      -- and report application of connection closure
      if self.res then self.res:finish() end
    end)
  end
end

--
-- bind the response to this connection
--

function Connection.prototype:_bind(response)

  -- disallow binding more than one response
  if self.res then
    response:finish()
    return
  end

p('BIND', self.id)

  -- bind response
  self.res = response

  -- any error in req closes the request
  response.req:once('error', function (err)
p('ERRINREQ', err)
    response.req:close()
  end)

  -- unbind the client when response is closed
  response:once('closed', function ()
    self:_unbind()
  end)

  -- any error in res closes the response,
  -- causing client unbind
  response:once('error', function (err, reason)
    -- number errors are soft WebSocket protocol errors
    -- N.B. no error here means connection is closed orderly
    if type(err) == 'number' and err ~= 1000 then
      self.options.onerror(self, err, reason)
    -- hard error
    elseif err then
p('ERR', err)
      -- TODO: implement?
    end
    response:finish()
  end)

  -- handle incoming messages
  response:on('message', function (payload)
    local status, result = pcall(self.options.codec.decode, payload)
    if status then
      for _, message in ipairs(result) do
        self.options.onmessage(self, message)
      end
    else
      self.options.onerror(self, result)
    end
  end)

  -- send opening frame for new connections
  if self.readyState == Connection.CONNECTING then
    -- TODO: send various options
    local HZ = require('json').stringify({
      sid = self.id,
      upgrades = { },
      pingTimeout = 10000,
      pingInterval = 5000,
    })
    self:_packet('open', HZ, function ()
      -- and report connection is open
      self.readyState = Connection.OPEN
      self.options.onopen(self)
      self._ping_timer = Timer.set_interval(5000, self._ping, self)
    end)
  end

  -- try to flush the buffer
  if self.readyState == Connection.OPEN and self.res then
    self:_flush()
  end

end

function Connection.prototype:_ping()
  self:_packet('ping')
end

--
-- disconnect the connection
--

function Connection.prototype:disconnect()
  -- mark connection as closing
  self.readyState = Connection.CLOSING
  if self.res then self.res:finish() end
end

--
-- unbind the response
--

function Connection.prototype:_unbind()
  --[[if self._timeout then
    Timer.clear_timer(self._timeout)
    self._timeout = nil
  end]]--
  if self.res then
p('UNBIND', self.id)
    self.res = nil
    Timer.set_timeout(self.options.disconnect_delay, self._purge, self)
    Timer.clear_timer(self._ping_timer)
  end
end

--
-- purge the connection
--

function Connection.prototype:_purge()
  if self.res or self.readyState > Connection.CLOSING then
    -- FIXME: this should not happen
    return
  end
--p('PURGE', self.id)
  self.readyState = Connection.CLOSED
  self.options.onclose(self)
  if self.id then
    connections[self.id] = nil
    self.id = nil
  end
end

--
-- flush outgoing buffer
--

function Connection.prototype:_flush()
  if self._flushing then return end
  local nmessages = #self._send_queue
  if nmessages > 0 then
    self._flushing = true
    local payload = self.options.codec.encode(self._send_queue)
p('FLUSH', payload)
    self.res:send(payload)
    -- TODO: consider resetting in callback to `send`
    self._send_queue = { }
    self._flushing = false
  end
end

--
-- send low-level frame.
-- implementations may override this to support custom encoding
--

function Connection.prototype:_packet(ptype, pdata, callback)
  -- put message in outgoing buffer
  Table.insert(self._send_queue, { type = ptype, data = pdata })
  -- try to flush the buffer
  if self.res then self:_flush() end
  if callback then callback() end
end

-- module
return Connection
