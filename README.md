WebSocket
=====

The middleware layer for handling WebSocket connections.

Usage
=====

Server
-----

```lua
local handle_websocket = require('websocket')

require('http').create_server('0.0.0.0', 8080, function (req, res)
  if req.url:sub(1, 3) == '/ws' then
    handle_websocket(req, res, function ()
      -- simple repeater
      req:on('message', function (message)
        res:send(message)
      end)
    end)
  else
    res:finish()
  end
end)
print('Open a browser, and try to create a WebSocket for ws://localhost:8080/ws')
```

Browser
-----

```js
var ws = new WebSocket('ws://localhost:8080/ws')
ws.onmessage = function (ev) {
  console.log('GOT', ev.data)
}
ws.send('foo')
```

License
-------

[MIT](websocket/license.txt)
