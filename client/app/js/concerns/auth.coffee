PokeBattle.events.on "connect", ->
  if PokeBattle.local
    console.log "Mocking login..."
    PokeBattle.socket.send('login')
