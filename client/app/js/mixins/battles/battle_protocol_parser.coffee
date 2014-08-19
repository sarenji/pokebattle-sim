@PokeBattle.mixins.BattleProtocolParser =
  update: (actions) ->
    return  if actions.length == 0
    @notify()
    hadStuff = (@updateQueue.length > 0)
    @updateQueue.push(actions...)
    @_update()  unless hadStuff

  _update: (wasAtBottom) ->
    view = @view
    queue = @updateQueue
    return  if !queue  # closed battle in the middle of getting updates
    if queue.length == 0
      view.renderUserInfo()
      view.resetPopovers()
      if wasAtBottom || view.skip? then view.chatView.scrollToBottom()
      if view.skip?
        delete view.skip
        view.$('.battle_pane').show()
      return
    wasAtBottom ||= view.chatView.isAtBottom()
    action = queue.shift()
    [ type, rest... ] = action
    protocol = (key  for key, value of Protocol when value == type)[0]
    try
      if window.localStorage.debug == 'true'
        console.log "Received protocol: #{protocol} with args: #{rest}"
    catch

    done = () =>
      return  if done.called
      done.called = true
      if view.skip?
        @_update.call(this, wasAtBottom)
      else
        # setTimeout 0 lets the browser breathe.
        setTimeout(@_update.bind(this, wasAtBottom), 0)

    doneTimeout = ->
      setTimeout(done, 0)

    doneSpeedTimeout = () =>
      if view.skip? || view.speed <= 1
        done()
      else
        setTimeout(done, (view.speed - 1) * 1000)

    try
      switch type
        when Protocol.CHANGE_HP
          [player, slot, newPercent] = rest
          pokemon = @getPokemon(player, slot)
          pokemon.set('percent', newPercent)
          if view.skip? then done() else setTimeout(done, 500)
        when Protocol.CHANGE_EXACT_HP
          [player, slot, newHP] = rest
          pokemon = @getPokemon(player, slot)
          pokemon.set('hp', newHP)
          done()
        when Protocol.SWITCH_OUT
          [player, slot] = rest
          view.switchOut(player, slot, done)
        when Protocol.SWITCH_IN
          # TODO: Get Pokemon data, infer which Pokemon it is.
          # Currently, it cheats with `fromSlot`.
          [player, toSlot, fromSlot] = rest
          team = @getTeam(player).get('pokemon').models
          [team[toSlot], team[fromSlot]] = [team[fromSlot], team[toSlot]]
          # TODO: Again, automatic.
          view.switchIn(player, toSlot, fromSlot, doneSpeedTimeout)
        when Protocol.CHANGE_PP
          [player, slot, moveIndex, newPP] = rest
          pokemon = @getPokemon(player, slot)
          pokemon.setPP(moveIndex, newPP)
          done()
        when Protocol.REQUEST_ACTIONS
          [validActions] = rest
          view.enableButtons(validActions)
          PokeBattle.notifyUser(PokeBattle.NotificationTypes.ACTION_REQUESTED, @id + "_" + @get('turn'))
          done()
        when Protocol.START_TURN
          [turn] = rest
          view.beginTurn(turn, doneTimeout)
        when Protocol.CONTINUE_TURN
          view.continueTurn(doneTimeout)
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
        when Protocol.BATTLE_EXPIRED
          view.announceExpiration(done)
        when Protocol.MOVE_SUCCESS
          [player, slot, targetSlots, moveName] = rest
          view.moveSuccess(player, slot, targetSlots, moveName, done)
        when Protocol.CANNED_TEXT
          cannedInteger = rest.splice(0, 1)
          view.parseCannedText(cannedInteger, rest, done)
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
          @receiveTeams(teams)
          view.preloadImages()
          if !@get('spectating')
            PokeBattle.notifyUser(PokeBattle.NotificationTypes.BATTLE_STARTED, @id)
          done()
        when Protocol.START_BATTLE
          view.removeTeamPreview()
          view.renderBattle()
          done()
        when Protocol.REARRANGE_TEAMS
          arrangements = rest
          @get('teams').forEach (team, i) ->
            team.rearrange(arrangements[i])
          done()
        when Protocol.RECEIVE_TEAM
          [team] = rest
          @receiveTeam(team)
          done()
        when Protocol.SPRITE_CHANGE
          [player, slot, newSpecies, newForme] = rest
          pokemon = @getPokemon(player, slot)
          pokemon.set('species', newSpecies)
          pokemon.set('forme', newForme)
          view.changeSprite(player, slot, newSpecies, newForme, done)
        when Protocol.BOOSTS
          [player, slot, deltaBoosts] = rest
          view.boost(player, slot, deltaBoosts, floatText: true)
          done()
        when Protocol.SET_BOOSTS
          [player, slot, boosts] = rest
          view.setBoosts(player, slot, boosts)
          done()
        when Protocol.RESET_BOOSTS
          [player, slot] = rest
          view.resetBoosts(player, slot)
          done()
        when Protocol.MOVESET_UPDATE
          [player, slot, movesetJSON] = rest
          pokemon = @getPokemon(player, slot)
          pokemon.set(movesetJSON)
          done()
        when Protocol.WEATHER_CHANGE
          [newWeather] = rest
          view.changeWeather(newWeather, done)
        when Protocol.TEAM_PREVIEW
          view.renderTeamPreview()
          done()
        when Protocol.ACTIVATE_ABILITY
          [player, slot, ability] = rest
          pokemon = @getPokemon(player, slot)
          pokemon.set('ability', ability)
          view.activateAbility(player, slot, ability, done)
        when Protocol.END_MOVE
          doneSpeedTimeout()
        else
          done()
    catch e
      console.error(e)
      console.error(e.stack)
      done()
    if wasAtBottom && !view.chatView.isAtBottom()
      view.chatView.scrollToBottom()
