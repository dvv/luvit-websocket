#!/usr/bin/env luvit

local Timer = require('timer')

local WS = {
  new = function (res, options)
    p('NEW', res and res.req.url)
    local conn = require('./lib/connection').new(res, options)
    return conn
  end,
  onopen = function (conn)
    p('OPEN', conn.id)
    --[[Timer.set_timeout(4000, function ()
      conn:send('От советского информбюро')
    end)]]--
  end,
  onclose = function (conn)
    p('CLOSE', conn.id)
  end,
  onerror = function (conn, code, reason)
    p('ERROR', conn.id, code, reason)
  end,
  onmessage = function (conn, message)
    p('<<<', conn.id, message)
    -- repeater
    for _, co in pairs(c) do
      co:send(message)
    end
    p('>>>', conn.id, message)
    -- close if 'quit' is got
    if message == 'quit' then
      conn:close(1002, 'Forced closure')
    end
  end,
}

local handle_websocket = require('./')(WS)
local handle_xhrsocket = require('./lib/xhr')(WS)

local handle_static = require('static')('/', {
  directory = __dirname .. '/example',
  is_cacheable = function (file) return false end,
})

require('http').create_server('0.0.0.0', 8080, function (req, res)
  if req.url:sub(1, 3) == '/ws' then
    handle_websocket(req, res)
  elseif req.url:sub(1, 3) == '/WS' then
    handle_xhrsocket(req, res)
  else
    handle_static(req, res, function ()
      res:set_code(404)
      res:finish()
    end)
  end
end)
print('Open a browser, and try to create a WebSocket for ws://localhost:8080/ws')
