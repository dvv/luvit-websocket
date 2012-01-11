WebSocket
=====

The middleware layer for handling WebSocket connections.

Usage
=====

Server
-----

```lua
local handle_websocket = require('./')({
  onopen = function (conn)
    p('OPEN', conn)
  end,
  onclose = function (conn)
    p('CLOSE', conn)
  end,
  onerror = function (conn, error)
    p('ERROR', conn, error)
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

require('http').create_server('0.0.0.0', 8080, function (req, res)
  if req.url:sub(1, 3) == '/ws' then
    handle_websocket(req, res)
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
ws.send('foo')
ws.send('quit')
```

License
-------

[MIT](websocket/license.txt)
