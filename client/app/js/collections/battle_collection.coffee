class @BattleCollection extends Backbone.Collection
  model: Battle

  initialize: (models, options) =>
    PokeBattle.socket.addEvents
      'team preview': @teamPreview
      'update battle': @updateBattle
      'spectate battle': @spectateBattle

  teamPreview: (socket, battleId, teams) =>
    battle = @get(battleId)
    if !battle
      console.log "Received events for #{battleId}, but no longer in battle!"
      return
    battle.notify()
    battle.trigger('team_preview', teams)

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
      when Protocol.REQUEST_ACTIONS
        [validActions] = rest
        console.log "ACTIONS REQUESTED:"
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
      when Protocol.POKEMON_ATTACH
        [player, slot, attachment] = rest
        view.attachPokemon(player, slot, attachment, done)
      when Protocol.TEAM_ATTACH
        [player, attachment] = rest
        view.attachTeam(player, attachment, done)
      when Protocol.BATTLE_ATTACH
        [attachment] = rest
        view.attachBattle(attachment, done)
      when Protocol.POKEMON_UNATTACH
        [player, slot, attachment] = rest
        view.unattachPokemon(player, slot, attachment, done)
      when Protocol.TEAM_UNATTACH
        [player, attachment] = rest
        view.unattachTeam(player, attachment, done)
      when Protocol.BATTLE_UNATTACH
        [attachment] = rest
        view.unattachBattle(attachment, done)
      when Protocol.BEGIN_BATTLE
        # TODO: This should be unnecessary later; the opponent's team should be
        # completely dark.
        [teams] = rest
        battle.receiveTeams(teams)
        done()
      else
        done()

  spectateBattle: (socket, id, numActive, index, teams) =>
    console.log "SPECTATING BATTLE #{id}."
    isSpectating = (if index? then false else true)
    # If not playing, pick a random index; it doesn't matter.
    index ?= Math.floor(2 * Math.random())
    battle = new Battle({id, numActive, socket, index, teams})
    # TODO: Figure out if player is spectating or not
    battle.set('spectating', isSpectating)
    createBattleWindow(this, battle)

createBattleWindow = (collection, battle) ->
  $battle = $(JST['battle_window'](battle: battle, window: window))
  $battle.appendTo $('#main-section')
  battle.view = new BattleView(el: $battle, model: battle)
  collection.add(battle)
