PokeBattle.events.on "connect", ->
  PokeBattle.socket.send('login', $.cookie("sessionid"))
