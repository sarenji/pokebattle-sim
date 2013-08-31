@BattleTower ?= {}

@BattleTower.initializeAuth ?= ->
  if BattleTower.local
    console.log "TODO: Mock login..."
    return
