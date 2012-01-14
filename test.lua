#!/usr/bin/env luvit

local handle_websocket = require('./')({
  new = function (res, options)
    p('NEW', res.req.url)
    local conn = require('./lib/connection').new(res, options)
  end,
  onopen = function (conn)
    p('OPEN', conn)
  end,
  onclose = function (conn)
    p('CLOSE', conn)
  end,
  onerror = function (conn, err)
    p('ERROR', conn, err)
  end,
  onmessage = function (conn, message)
    p('<<<', message)
    -- repeater
    conn:send(message)
    p('>>>', message)
    -- close if 'quit' is got
    if message == 'quit' then
      conn:close(1002, 'Forced closure')
    end
  end,
})

local handle_static = require('static')('/', {
  directory = __dirname .. '/example',
})

require('http').create_server('0.0.0.0', 8080, function (req, res)
  if req.url:sub(1, 3) == '/ws' then
    handle_websocket(req, res)
  else
    handle_static(req, res, function ()
      res:set_code(404)
      res:finish()
    end)
  end
end)
print('Open a browser, and try to create a WebSocket for ws://localhost:8080/ws')
