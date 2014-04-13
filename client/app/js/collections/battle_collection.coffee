class @BattleCollection extends Backbone.Collection
  model: Battle

  initialize: (models, options) =>
    PokeBattle.socket.addEvents
      'updateBattle': @updateBattle
      'spectateBattle': @spectateBattle
      'joinBattle': @joinBattle
      'leaveBattle': @leaveBattle
    @updateQueue = {}
    @on 'add', (model) =>
      @updateQueue[model.id] = []
    @on 'remove', (model) =>
      delete @updateQueue[model.id]
      PokeBattle.socket.send('leaveBattle', model.id)

  updateBattle: (socket, battleId, actions) =>
    battle = @get(battleId)
    if !battle
      console.log "Received events for #{battleId}, but no longer in battle!"
      return
    battle.notify()
    @queueBattleUpdates(battle, actions)

  queueBattleUpdates: (battle, actions) =>
    queue = @updateQueue[battle.id]
    hadStuff = (queue.length > 0)
    queue.push(actions...)
    if !hadStuff then @_updateBattle(battle)

  _updateBattle: (battle, wasAtBottom) =>
    view = battle.view
    queue = @updateQueue[battle.id]
    if queue.length == 0
      view.renderUserInfo()
      if wasAtBottom || view.skip? then view.chatView.scrollToBottom()
      if view.skip?
        delete view.skip
        view.$('.battle_pane').show()
      return
    wasAtBottom ||= view.chatView.isAtBottom()
    action = queue.shift()
    [ type, rest... ] = action
    protocol = (key  for key, value of Protocol when value == type)[0]
    console.log "Received protocol: #{protocol}"

    done = () =>
      return  if done.called
      done.called = true
      @_updateBattle.call(this, battle, wasAtBottom)

    try
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
          view.enableButtons(validActions)
          PokeBattle.notifyUser(PokeBattle.NotificationTypes.ACTION_REQUESTED, battle.id + "_" + battle.get('turn'))
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
        when Protocol.TIMER_WIN
          [winner] = rest
          view.announceTimer(winner, done)
        when Protocol.UPDATE_TIMERS
          timers = rest
          view.updateTimers(timers, done)
        when Protocol.PAUSE_TIMER
          [player] = rest
          view.pauseTimer(player)
          done()
        when Protocol.RESUME_TIMER
          [player] = rest
          view.resumeTimer(player)
          done()
        when Protocol.MOVE_SUCCESS
          [player, slot, targetSlots, moveName] = rest
          view.moveSuccess(player, slot, targetSlots, moveName, done)
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
        when Protocol.INITIALIZE
          # TODO: Handle non-team-preview
          [teams] = rest
          battle.receiveTeams(teams)
          if !battle.get('spectating')
            PokeBattle.notifyUser(PokeBattle.NotificationTypes.BATTLE_STARTED, battle.id)
          done()
        when Protocol.START_BATTLE
          view.removeTeamPreview()
          view.renderBattle()
          done()
        when Protocol.REARRANGE_TEAMS
          arrangements = rest
          for team, i in battle.teams
            team.rearrange(arrangements[i])
          done()
        when Protocol.RECEIVE_TEAM
          [team] = rest
          battle.receiveTeam(team)
          done()
        when Protocol.SPRITE_CHANGE
          [player, slot, newSpecies, newForme] = rest
          pokemon = battle.getPokemon(player, slot)
          pokemon.set('name', newSpecies)
          pokemon.set('forme', newForme)
          view.changeSprite(player, slot, newSpecies, newForme)
          done()
        when Protocol.BOOSTS
          [player, slot, deltaBoosts] = rest
          view.boost(player, slot, deltaBoosts, done)
        when Protocol.RESET_BOOSTS
          [player, slot] = rest
          view.resetBoosts(player, slot, done)
        when Protocol.MOVESET_UPDATE
          [player, slot, movesetJSON] = rest
          pokemon = battle.getPokemon(player, slot)
          pokemon.set(movesetJSON)
          done()
        when Protocol.WEATHER_CHANGE
          [newWeather] = rest
          view.changeWeather(newWeather, done)
        when Protocol.TEAM_PREVIEW
          view.renderTeamPreview()
          done()
        when Protocol.CANCEL_SUCCESS
          view.cancelSuccess(done)
        else
          done()
    catch e
      throw e  if document.domain == 'localhost'
      console.error(e)
      done()
    view.resetPopovers()
    if wasAtBottom && !view.chatView.isAtBottom()
      view.chatView.scrollToBottom()

  spectateBattle: (socket, id, generation, numActive, index, playerIds, spectators, log) =>
    console.log "SPECTATING BATTLE #{id}."
    isSpectating = (if index? then false else true)
    # If not playing, pick a random index; it doesn't matter.
    index ?= Math.floor(2 * Math.random())
    battle = new Battle({id, generation, numActive, socket, index, playerIds, spectators})
    battle.set('spectating', isSpectating)
    createBattleWindow(this, battle)
    if log.length > 0
      battle.view.skip = 0
      battle.view.$('.battle_pane').hide()
      @queueBattleUpdates(battle, log)

  joinBattle: (socket, id, user) =>
    battle = @get(id)
    if !battle
      console.log "Received events for #{id}, but no longer in battle!"
      return
    battle.spectators.add(id: user)

  leaveBattle: (socket, id, user) =>
    battle = @get(id)
    if !battle
      console.log "Received events for #{id}, but no longer in battle!"
      return
    battle.spectators.remove(id: user)

createBattleWindow = (collection, battle) ->
  $battle = $(JST['battle_window'](battle: battle, window: window))
  $battle.appendTo $('#main-section')
  battle.view = new BattleView(el: $battle, model: battle)
  collection.add(battle)
