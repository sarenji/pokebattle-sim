# Send primus event when leaving battles.
PokeBattle.battles.on 'remove', (battle) ->
  PokeBattle.primus.send('leaveBattle', battle.id)

# Event listeners
PokeBattle.primus.on 'updateBattle', (id, queue) ->
  battle = PokeBattle.battles.get(id)
  if !battle
    console.log "Received events for #{id}, but no longer in battle!"
    return
  battle.update(queue)

# Create a BattleView when spectating a battle
PokeBattle.primus.on 'spectateBattle', (id, format, numActive, index, playerIds, spectators, log) ->
  if PokeBattle.battles.get(id)
    console.log "Already spectating battle #{id}!"
    return
  battle = new Battle({id, format, numActive, index, playerIds, spectators})

  # Create BattleView
  $battle = $(JST['battle_window']({battle, window}))
  $('#main-section').append($battle)
  battle.view = new BattleView(el: $battle, model: battle)
  battle.view.skip = 0
  battle.view.$('.battle_pane').hide()

  # Add to collection
  PokeBattle.battles.add(battle)

  # Update log
  battle.update(log)

PokeBattle.primus.on 'joinBattle', (id, user) ->
  battle = PokeBattle.battles.get(id)
  if !battle
    console.log "Received events for #{id}, but no longer in battle!"
    return
  battle.spectators.add(user)

PokeBattle.primus.on 'leaveBattle', (id, user) ->
  battle = PokeBattle.battles.get(id)
  if !battle
    console.log "Received events for #{id}, but no longer in battle!"
    return
  battle.spectators.remove(id: user)

PokeBattle.primus.on 'updateTimers', (id, timers) ->
  battle = PokeBattle.battles.get(id)
  if !battle
    console.log "Received events for #{id}, but no longer in battle!"
    return
  battle.view.updateTimers(timers)

PokeBattle.primus.on 'resumeTimer', (id, player) ->
  battle = PokeBattle.battles.get(id)
  if !battle
    console.log "Received events for #{id}, but no longer in battle!"
    return
  battle.view.resumeTimer(player)

PokeBattle.primus.on 'pauseTimer', (id, player, timeSinceLastAction) ->
  battle = PokeBattle.battles.get(id)
  if !battle
    console.log "Received events for #{id}, but no longer in battle!"
    return
  battle.view.pauseTimer(player, timeSinceLastAction)
