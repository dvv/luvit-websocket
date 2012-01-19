
int createtable(lua_State *L) {
  int narray, nhash;
  narray = luaL_optint(L, 1, 0);
  nhash = luaL_optint(L, 2, 0);
  lua_createtable(L, narray, nhash);
  return 1;
}
