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
  uint32_t mask = luaL_checkint(L, 3);
  if (mask) mask = 0x80;
  mask = 0;

  uint32_t i;

  // TODO: other than 1 types
  p[0] = 0x80 | 0x01;

  // compose header
  if (len < 126) {
    p[1] = mask | len;
    p += 2;
  } else if (len < 65536) {
    p[1] = mask | 0x7E;
    p[2] = (len >> 8) & 0xFF;
    p[3] = len & 0xFF;
    p += 4;
  } else {
    p[1] = mask | 0x7F;
    uint32_t len2 = len;
    for (i = 8; i > 0; --i) {
      p[i+1] = len2 & 0xFF;
      len2 = len2 >> 8;
    }
    p += 10;
  }

  // mask the buffer content?
  if (mask) {

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

  }

  return 0;
}

static int xor32s(lua_State *L) {

  const char *p = luaL_checkstring(L, 1);
  const char *key = luaL_checkstring(L, 2);
  // FIXME: checklong?
  uint32_t len = luaL_checkint(L, 3);

  // xor the buffer
  uint32_t i, ki;
  for (i = 0, ki = 0; i < len; ++i) {
    ((uint8_t *)p)[i] ^= key[ki];
    if (++ki > 3) ki = 0;
  }

  lua_pushstring(L, p);
  return 1;

  //return 0;
}

static int xor32(lua_State *L) {

  const char *p = luaL_checkstring(L, 1);
  uint32_t mask = luaL_checkint(L, 2);
  // FIXME: checklong?
  uint32_t len = luaL_checkint(L, 3);

  // xor the buffer
  const uint8_t *key = (const uint8_t *)&mask;
  uint32_t i, ki;
  for (i = 0, ki = 0; i < len; ++i) {
    ((uint8_t *)p)[i] ^= key[ki];
    if (++ki > 3) ki = 0;
  }

  lua_pushstring(L, p);
  return 1;

  //return 0;
}

int createtable(lua_State *L) {
  int narray, nhash;
  narray = luaL_optint(L, 1, 0);
  nhash = luaL_optint(L, 2, 0);
  lua_createtable(L, narray, nhash);
  return 1;
}

////////////////////////////////////////////////////////////////////////////////


static const luaL_reg exports[] = {
  {"encode", encode},
  {"xor32", xor32},
  {"xor32s", xor32s},
  {"createtable", createtable},
  {NULL, NULL}
};

LUALIB_API int luaopen_hybi10(lua_State *L) {

  lua_newtable(L);
  luaL_register(L, NULL, exports);

  // return the new module
  return 1;
}
