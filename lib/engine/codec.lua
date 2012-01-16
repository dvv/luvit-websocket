local Table = require('table')

---
-- Packet types.
--

local packets = {
  open =     0,    -- non-ws
  close =    1,    -- non-ws
  ping =     2,
  pong =     3,
  message =  4,
  error =    5,
  noop =     6,
}

-- provide inverse map, to ease lookup
for k, v in pairs(packets) do packets[v] = k end

---
-- Premade error packet.
--

local err = { type = 'error', data = 'parser error' }

---
-- Encodes a packet.
--
--     <packet type id> [ `:` <data> ]
--
-- Example:
--
--     5:hello world
--     3
--     4
--
-- @api private
--

local function encodePacket(packet)
  local encoded = packets[packet.type]
  if not encoded then return '0' end

  -- data fragment is optional
  if packet.data ~= nil then
    encoded = encoded .. packet.data
  end

  return tostring(encoded)
end

---
-- Decodes a packet.
--
-- @return {Object} with `type` and `data` (if any)
-- @api private
--

local function decodePacket(data)
  local typ = data:byte(1) - 0x30
  if typ < 0 or typ > 9 or not packets[typ] then
    -- parser error - ignoring packet
    return err
  end
  if #data > 1 then
    return { type = packets[typ], data = data:sub(2) }
  else
    return { type = packets[typ] }
  end
end

---
-- Encodes multiple messages (payload).
-- 
--     <length>:data
--
-- Example:
--
--     11:hello world2:hi
--
-- @param {Array} packets
-- @api private
--

function encodePayload(packets)
  if #packets == 0 then
    return '0:'
  end
  local encoded = { }
  for i, packet in ipairs(packets) do
    local message = encodePacket(packet)
    Table.insert(encoded, #message)
    Table.insert(encoded, ':')
    Table.insert(encoded, message)
  end
  return Table.concat(encoded)
end

---
-- Decodes data when a payload is maybe expected.
--
-- @param {String} data
-- @return {Array} packets
-- @api public
--

function decodePayload(data)
  local ret = { err }

  if data == '' then
    -- parser error - ignoring payload
    return ret
  end

  local packets = { }
  local buf = data
  local n, msg, packet

  -- FIXME: lua is not good at mutable strings. Consider lbuffers
  while #buf do
    local colon = (buf:find(':', 1, true))
    if not colon then break end

    n = tonumber(buf:sub(1, colon - 1))
    if not n then
      -- parser error - ignoring payload
      return ret
    end

    msg = buf:sub(colon + 1, colon + n)

    if n ~= #msg then
      -- parser error - ignoring payload
      return ret
    end

    buf = buf:sub(colon + n + 1)

    if #msg then
      packet = decodePacket(msg)

      if err.type == packet.type and err.data == packet.data then
        -- parser error in individual packet - ignoring payload
        return ret
      end

      Table.insert(packets, packet)
    end
  end

  if #buf ~= 0 then
    -- parser error - ignoring payload
    return ret
  end

  return packets
end

-- module
return {
  packets = packets,
  encode_packet = encodePacket,
  decode_packet = decodePacket,
  encode = encodePayload,
  decode = decodePayload,
  OPEN = packets.open,
  CLOSE = packets.close,
  MESSAGE = packets.message,
}
