class @BattleCollection extends Backbone.Collection
  model: Battle

  _.extend(this.prototype, PokeBattle.mixins.BattleProtocolParser)

  initialize: (models, options) =>
    PokeBattle.primus.on('updateBattle', @updateBattle)
    PokeBattle.primus.on('spectateBattle', @spectateBattle)
    PokeBattle.primus.on('joinBattle', @joinBattle)
    PokeBattle.primus.on('leaveBattle', @leaveBattle)
    PokeBattle.primus.on('updateTimers', @updateTimers)
    PokeBattle.primus.on('resumeTimer', @resumeTimer)
    PokeBattle.primus.on('pauseTimer', @pauseTimer)
    @updateQueue = {}
    @on 'add', (model) =>
      @updateQueue[model.id] = []
    @on 'remove', (model) =>
      delete @updateQueue[model.id]
      PokeBattle.primus.send('leaveBattle', model.id)

  isPlaying: =>
    @find((battle) -> battle.isPlaying())?

  playingBattles: =>
    @filter((battle) -> battle.isPlaying())

  updateBattle: (battleId, actions) =>
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
    if !hadStuff then @__updateBattle(battle)

  spectateBattle: (id, generation, numActive, index, playerIds, spectators, log) ->
    console.log "SPECTATING BATTLE #{id}."
    isSpectating = (if index? then false else true)
    # If not playing, pick a random index; it doesn't matter.
    index ?= Math.floor(2 * Math.random())
    battle = new Battle({id, generation, numActive, index, playerIds, spectators})
    battle.set('spectating', isSpectating)
    @createBattleWindow(battle)
    if log.length > 0
      battle.view.skip = 0
      battle.view.$('.battle_pane').hide()
      @queueBattleUpdates(battle, log)
    battle

  joinBattle: (id, user) =>
    battle = @get(id)
    if !battle
      console.log "Received events for #{id}, but no longer in battle!"
      return
    battle.spectators.add(user)

  leaveBattle: (id, user) =>
    battle = @get(id)
    if !battle
      console.log "Received events for #{id}, but no longer in battle!"
      return
    battle.spectators.remove(id: user)

  updateTimers: (id, timers) =>
    battle = @get(id)
    if !battle
      console.log "Received events for #{id}, but no longer in battle!"
      return
    battle.view.updateTimers(timers)

  resumeTimer: (id, player) =>
    battle = @get(id)
    if !battle
      console.log "Received events for #{id}, but no longer in battle!"
      return
    battle.view.resumeTimer(player)

  pauseTimer: (id, player, timeSinceLastAction) =>
    battle = @get(id)
    if !battle
      console.log "Received events for #{id}, but no longer in battle!"
      return
    battle.view.pauseTimer(player, timeSinceLastAction)

  createBattleWindow: (battle) ->
    backgroundNumber = @generateBackgroundNumber(battle.id, 6)
    $battle = $(JST['battle_window']({battle, window, backgroundNumber}))
    $battle.appendTo $('#main-section')
    battle.view = new BattleView(el: $battle, model: battle)
    @add(battle)

  generateBackgroundNumber: (battleId, numBackgrounds) ->
    number = parseInt(battleId[...6], 16)
    number % numBackgrounds
