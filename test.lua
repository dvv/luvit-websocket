#!/usr/bin/env luvit

local Timer = require('timer')

local handle_websocket = require('websocket').handler

require('http').create_server('0.0.0.0', 8080, function (req, res)
  if req.url:sub(1, 3) == '/ws' then
    handle_websocket(req, res, function ()
      Timer.set_interval(1000, function ()
        res:send('.')
      end)
      -- simple repeater
      req:on('message', function (message)
        p('<', message)
        res:send(message)
        p('>', message)
      end)
    end)
  else
    res:finish()
  end
end)
print('Open a browser, and try to create a WebSocket for ws://localhost:8080/ws')
