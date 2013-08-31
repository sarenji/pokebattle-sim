@PokeBattle ?= {}

@PokeBattle.initializeAuth ?= ->
  if PokeBattle.local
    console.log "Mocking login..."
    PokeBattle.socket.send('login')
    return
