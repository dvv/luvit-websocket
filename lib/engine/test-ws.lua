#!/usr/bin/env luvit

_G.equal = function(a, b)
  return a == b
end

_G.deep_equal = function(expected, actual)
  if type(expected) == 'table' and type(actual) == 'table' then
    if #expected ~= #actual then return false end
    for k, v in pairs(expected) do
      if not deep_equal(v, actual[k]) then return false end
    end
    return true
  else
    return equal(expected, actual)
  end
end

local P = require('./lib/codec')

local x = {type = 'message', data = 1}
assert(equal(P.encode_packet(x), '41'))
assert(equal(P.encode({x}), '2:41'))

assert(deep_equal(P.decode_packet(P.encode_packet({type='message',data=''})), {type='message',data=''}))
assert(deep_equal(P.decode_packet('41'), {type='message',data='1'}))
assert(deep_equal(P.decode_packet('j:unk4:1'), {type='error',data='parser error'}))
assert(deep_equal(P.decode_packet('91'), {type='error',data='parser error'}))
assert(deep_equal(P.decode('2:41'), {{type='message',data='1'}}))
assert(deep_equal(P.decode('2:4125:4Привет семье!'), {{type='message',data='1'},{type='message',data='Привет семье!'}}))

local xx = { {type = 'message', data = 'Привет, мир!'}, {type = 'message', data = '\000\001\002\200'} }
assert(deep_equal(P.decode(P.encode(xx)), xx))
