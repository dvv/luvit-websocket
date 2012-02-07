return {
  name = 'websocket',
  version = '0.0.1',
  description = "WebSocket protocol library",
  author = "Vladimir Dronnikov <dronnikov@gmail.com>",
  dependencies = {
    crypto  = "https://github.com/dvv/luvit-crypto/zipball/master",
    cmdline = "https://github.com/dvv/luvit-cmdline/zipball/master",
  },
  bin = {
    ws = './bin/ws',
  },
}
