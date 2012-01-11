/*
 *  Copyright 2012 Vladimir Dronnikov. All Rights Reserved.
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 *
 */

#include <stdint.h>
#include <string.h>
#include <stdlib.h>

#include <lua.h>
#include <lauxlib.h>

static int encode(lua_State *L) {

  uint8_t *p = (uint8_t *)luaL_checkstring(L, 1);
  // FIXME: checklong?
  uint32_t len = luaL_checkint(L, 2);

  uint32_t i;

  // compose header
  if (len < 126) {
    p[0] = 0x80 + 1;
    p[1] = 0x80 | len;
    p += 2;
  } else if (len < 65536) {
    p[0] = 0x80 + 1;
    p[1] = 0x80 | 0x7E;
    p[2] = (len >> 8) & 0xFF;
    p[3] = len & 0xFF;
    p += 4;
  } else {
    p[0] = 0x80 + 1;
    p[1] = 0x80 | 0x7F;
    uint32_t len2 = len;
    for (i = 8; i > 0; --i) {
      p[i+1] = len2 & 0xFF;
      len2 = len2 >> 8;
    }
    p += 10;
  }

  // create mask
  uint32_t ki;
  uint8_t *key = p;
  // TODO: srand? or read /dev/urandom?
  for (ki = 0; ki < 4; ++ki) {
    key[ki] = rand() & 0xFF;
  }
  p += 4;

  // mask buffer content
  for (i = 0, ki = 0; i < len; ++i) {
    p[i] ^= key[ki];
    if (++ki > 3) ki = 0;
  }

  return 0;
}

static int mask(lua_State *L) {

  //uint8_t *p = (uint8_t *)luaL_checkstring(L, 1);
  const char *p = luaL_checkstring(L, 1);
  const char *key = luaL_checkstring(L, 2);
  // FIXME: checklong?
  uint32_t len = luaL_checkint(L, 3);

  // mask buffer content
  uint32_t i, ki;
  for (i = 0, ki = 0; i < len; ++i) {
    ((uint8_t *)p)[i] ^= key[ki];
    if (++ki > 3) ki = 0;
  }

  lua_pushstring(L, p);
  return 1;

  //return 0;
}

////////////////////////////////////////////////////////////////////////////////


static const luaL_reg exports[] = {
  {"encode", encode},
  {"mask", mask},
  {NULL, NULL}
};

LUALIB_API int luaopen_hybi10(lua_State *L) {

  lua_newtable(L);
  luaL_register(L, NULL, exports);

  // return the new module
  return 1;
}
