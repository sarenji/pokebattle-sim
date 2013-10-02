class @BattleCollection extends Backbone.Collection
  model: Battle

  initialize: (models, options) =>
    PokeBattle.socket.addEvents
      'team preview': @teamPreview
      'update battle': @updateBattle
      'spectate battle': @spectateBattle
      'join battle': @joinBattle
      'leave battle': @leaveBattle
    @on 'remove', (model) ->
      PokeBattle.socket.send('leave battle', model.id)

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
      view.renderUserInfo()
      if wasAtBottom || view.skip? then view.chatView.scrollToBottom()
      if view.skip?                then delete view.skip
      return
    wasAtBottom ||= view.chatView.isAtBottom()
    action = actions.shift()
    [ type, rest... ] = action
    protocol = (key  for key, value of Protocol when value == type)[0]
    console.log "Received protocol: #{protocol}"

    done = @_updateBattle.bind(this, battle, actions, wasAtBottom)
    switch type
      when Protocol.CHANGE_HP
        [player, slot, newPixels] = rest
        pokemon = battle.getPokemon(player, slot)
        oldPixels = pokemon.get('pixels')
        pokemon.set('pixels', newPixels)
        # TODO: Have this be called automatically.
        view.changeHP(player, slot, oldPixels, done)
      when Protocol.CHANGE_EXACT_HP
        [player, slot, newHP] = rest
        pokemon = battle.getPokemon(player, slot)
        pokemon.set('hp', newHP)
        done()
      when Protocol.SWITCH_OUT
        [player, slot] = rest
        view.switchOut(player, slot, done)
      when Protocol.SWITCH_IN
        # TODO: Get Pokemon data, infer which Pokemon it is.
        # Currently, it cheats with `fromSlot`.
        [player, toSlot, fromSlot] = rest
        team = battle.getTeam(player).models
        [team[toSlot], team[fromSlot]] = [team[fromSlot], team[toSlot]]
        # TODO: Again, automatic.
        view.switchIn(player, toSlot, fromSlot, done)
      when Protocol.CHANGE_PP
        [player, slot, moveIndex, newPP] = rest
        pokemon = battle.getPokemon(player, slot)
        pokemon.setPP(moveIndex, newPP)
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
        view.removeTeamPreview()
        # TODO: This should be unnecessary later; the opponent's team should be
        # completely dark.
        [teams] = rest
        battle.receiveTeams(teams)
        view.renderBattle()
        done()
      when Protocol.RECEIVE_TEAM
        [team] = rest
        battle.receiveTeam(team)
        done()
      else
        done()
    if wasAtBottom && !view.chatView.isAtBottom()
      view.chatView.scrollToBottom()

  spectateBattle: (socket, id, numActive, index, teams, spectators, log) =>
    console.log "SPECTATING BATTLE #{id}."
    isSpectating = (if index? then false else true)
    # If not playing, pick a random index; it doesn't matter.
    index ?= Math.floor(2 * Math.random())
    battle = new Battle({id, numActive, socket, index, teams, spectators})
    battle.set('spectating', isSpectating)
    createBattleWindow(this, battle)
    if log.length > 0
      battle.view.skip = 0
      @_updateBattle(battle, log, false)

  joinBattle: (socket, id, user) =>
    battle = @get(id)
    if !battle
      console.log "Received events for #{id}, but no longer in battle!"
      return
    battle.spectators.add(user)

  leaveBattle: (socket, id, user) =>
    battle = @get(id)
    if !battle
      console.log "Received events for #{id}, but no longer in battle!"
      return
    battle.spectators.remove(user)

createBattleWindow = (collection, battle) ->
  $battle = $(JST['battle_window'](battle: battle, window: window))
  $battle.appendTo $('#main-section')
  battle.view = new BattleView(el: $battle, model: battle)
  collection.add(battle)
