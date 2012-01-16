local Table = require('table')

return function (options)

  return function (req, res)

    res.req = req

    -- get connection
    -- TODO: FIXXXX
    local id = req.url:sub(5)
p('GETCONN', id)
    local conn = require('./connection').get(id)

    --
    -- incoming data
    --

    if req.method == 'POST' then

      -- no such connection?
      if not conn then
        -- bail out
        res:set_code(404)
        res:finish()
        return
      end

      -- collect passed data
      local data = ''
      req:on('data', function (chunk)
        data = data .. chunk
      end)
      -- data collected
      req:on('end', function ()
        -- get frame type
        local t = data:sub(1, 2)
        local payload = data:sub(3)
        -- close frame?
        if t == 'c:' then
          local i, j = payload:find('^%d+')
          local code, reason
          if i then
            code = tonumber(payload:sub(1, j))
            if payload:sub(j + 1, j + 1) == ':' then
              reason = payload:sub(j + 2)
            end
          end
          if type(code) == 'number' and code ~= 1000 then
            conn.options.onerror(conn, code, reason)
          end
          -- disconnect
          conn:disconnect()
        -- message frame
        elseif t == 'm:' then
          conn.options.onmessage(conn, payload)
        -- unknown frame. ignore
        else
        end
        res:write_head(204, {
          ['Content-Type'] = 'text/plain; charset=UTF-8',
        })
        res:finish()
      end)

    --
    -- outgoing data
    --

    elseif req.method == 'GET' then

      -- define sender
      res.send = function (self, data, callback)
        self:finish(data, callback)
      end

      -- existing connection
      if conn then

        -- send response headers
        res.auto_chunked = false
        res:write_head(200, {
          ['Content-Type'] = 'text/plain; charset=UTF-8'
        })

        -- bind response to the connection
        conn:_bind(res)

      -- new connection?
      elseif id == '' then

        conn = options.new(nil, options)

        -- override connection packet sender
        conn._packet = function (self, ptype, pdata, callback)
--p('PACKET', ptype, pdata)
          if ptype == 'message' then
            self.res:send('m:' .. Table.concat(pdata, ','), callback)
          elseif ptype == 'open' then
            local s = 'o:'
            -- TODO: urlencode pdata
            s = s .. 'id=' .. self.id .. '&interval=10'
            self.res:send(s, callback)
          elseif ptype == 'close' then
            local s = 'c:'
            self.res:send(s, callback)
          elseif callback then
            callback()
          end
        end

        -- bind response to the connection
        conn:_bind(res)

      -- no such connection
      else

        -- bail out
        res:set_code(404)
        res:finish()

      end

    --
    -- invalid verb
    --

    else

      res:set_code(405)
      res:finish()

    end

  end

end
