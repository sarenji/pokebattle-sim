@BattleTower ?= {}

@BattleTower.initializeAuth ?= ->
  if BattleTower.local
    console.log "Mocking login..."
    BattleTower.socket.send('login')
    return
