class @BattleCollection extends Backbone.Collection
  model: Battle

  initialize: (models, options) =>
    PokeBattle.socket.addEvents
      'start battle': @startBattle
      'update battle': @updateBattle
      'spectate battle': @spectateBattle

  startBattle: (socket, id, numActive, index, teams) =>
    console.log "BATTLE STARTED."
    battle = new Battle({id, numActive, socket, index, teams})
    createBattleWindow(this, battle)

  updateBattle: (socket, battleId, actions) =>
    battle = @get(battleId)
    if !battle
      console.log "Received events for #{battleId}, but no longer in battle!"
      return
    battle.notify()
    @_updateBattle(battle, actions)

  _updateBattle: (battle, actions, wasAtBottom) =>
    view = battle.view
    if actions.length == 0
      if wasAtBottom then view.chatView.scrollToBottom()
      return
    wasAtBottom ||= view.chatView.isAtBottom()
    action = actions.shift()
    [ type, rest... ] = action
    protocol = (key  for key, value of Protocol when value == type)[0]
    console.log "Received protocol: #{protocol}"

    done = @_updateBattle.bind(this, battle, actions, wasAtBottom)
    switch type
      when Protocol.CHANGE_HP
        [player, slot, newHP] = rest
        battle.getPokemon(player, slot).hp = newHP
        # TODO: Have this be called automatically.
        view.changeHP(player, slot, done)
      when Protocol.SWITCH_OUT
        [player, slot] = rest
        view.switchOut(player, slot, done)
      when Protocol.SWITCH_IN
        # TODO: Get Pokemon data, infer which Pokemon it is.
        # Currently, it cheats with `fromSlot`.
        [player, toSlot, fromSlot] = rest
        team = battle.getTeam(player).pokemon
        [team[toSlot], team[fromSlot]] = [team[fromSlot], team[toSlot]]
        # TODO: Again, automatic.
        view.switchIn(player, toSlot, done)
      when Protocol.CHANGE_PP
        [player, slot, moveIndex, newPP] = rest
        pokemon = battle.getPokemon(player, slot)
        pokemon.pp[moveIndex] = newPP
        done()
      when Protocol.REQUEST_ACTION
        [validActions] = rest
        console.log "ACTION REQUESTED:"
        console.log validActions
        view.enableButtons(validActions)
        done()
      when Protocol.START_TURN
        [turn] = rest
        view.beginTurn(turn, done)
      when Protocol.RAW_MESSAGE
        [message] = rest
        view.addLog("#{message}<br>")
        done()
      when Protocol.FAINT
        [player, slot] = rest
        view.faint(player, slot, done)
      when Protocol.MAKE_MOVE
        # TODO: Send move id instead
        [player, slot, moveName] = rest
        view.logMove(player, slot, moveName, done)
      when Protocol.END_BATTLE
        [winner] = rest
        view.announceWinner(winner, done)
      when Protocol.FORFEIT_BATTLE
        [forfeiter] = rest
        view.announceForfeit(forfeiter, done)
      when Protocol.MOVE_SUCCESS
        [player, slot, targetSlot] = rest
        view.moveSuccess(player, slot, targetSlot, done)
      when Protocol.EFFECT_END
        [player, slot, effect] = rest
        view.endEffect(player, slot, effect, done)

  spectateBattle: (socket, id, numActive, teams) =>
    console.log "SPECTATING BATTLE #{id}."
    # Pick a random index; it doesn't matter too much.
    index = Math.round(Math.random())
    battle = new Battle({id, numActive, socket, index, teams})
    battle.set('spectating', true)
    createBattleWindow(this, battle)

createBattleWindow = (collection, battle) ->
  $battle = $(JST['battle_window'](battle: battle, window: window))
  $battle.appendTo $('#main-section')
  battle.view = new BattleView(el: $battle, model: battle)
  collection.add(battle)
