PokeBattle.events.on "connect", ->
  PokeBattle.socket.send('login', PokeBattle.user.token)
