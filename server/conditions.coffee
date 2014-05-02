{_} = require('underscore')
{Conditions} = require('../shared/conditions')
{Protocol} = require('../shared/protocol')
pbv = require('../shared/pokebattle_values')
gen = require('./generations')
alts = require('./alts')

ConditionHash = {}

createCondition = (condition, effects = {}) ->
  ConditionHash[condition] = effects

# Attaches each condition to the Battle facade.
@attach = (battleFacade) ->
  battle = battleFacade.battle
  for condition in battle.conditions
    if condition not of ConditionHash
      throw new Error("Undefined condition: #{condition}")
    hash = ConditionHash[condition] || {}
    # Attach each condition's event listeners
    for eventName, callback of hash.attach
      battle.on(eventName, callback)

    # Extend battle with each function
    # TODO: Attach to prototype, and only once.
    for funcName, funcRef of hash.extend
      battle[funcName] = funcRef

    for funcName, funcRef of hash.extendFacade
      battleFacade[funcName] = funcRef

# validates an entire team
@validateTeam = (conditions, team, genData) ->
  errors = []
  for condition in conditions
    if condition not of ConditionHash
      throw new Error("Undefined condition: #{condition}")
    validator = ConditionHash[condition].validateTeam
    continue  if !validator
    errors.push(validator(team, genData)...)
  return errors

# validates a single pokemon
@validatePokemon = (conditions, pokemon, genData, prefix) ->
  errors = []
  for condition in conditions
    if condition not of ConditionHash
      throw new Error("Undefined condition: #{condition}")
    validator = ConditionHash[condition].validatePokemon
    continue  if !validator
    errors.push(validator(pokemon, genData, prefix)...)
  return errors

createCondition Conditions.PBV_1000,
  validateTeam: (team, genData) ->
    errors = []
    if pbv.determinePBV(genData, team) > 1000
      errors.push "Total team PBV cannot surpass 1,000."
    if team.length != 6
      errors.push "Your team must have 6 pokemon"
    return errors

createCondition Conditions.SLEEP_CLAUSE,
  attach:
    initialize: ->
      for team in @getTeams()
        for p in team.pokemon
          p.attach(@getAttachment("SleepClause"))

createCondition Conditions.SPECIES_CLAUSE,
  validateTeam: (team, genData) ->
    errors = []
    species = team.map((p) -> p.name)
    species.sort()
    for i in [1...species.length]
      speciesName = species[i - 1]
      if speciesName == species[i]
        errors.push("Cannot have the same species: #{speciesName}")
      while speciesName == species[i]
        i++
    return errors

createCondition Conditions.EVASION_CLAUSE,
  validatePokemon: (pokemon, genData, prefix) ->
    {moves, ability} = pokemon
    errors = []

    # Check evasion abilities
    if ability in [ "Moody" ]
      errors.push("#{prefix}: #{ability} is banned under Evasion Clause.")

    # Check evasion moves
    for moveName in moves || []
      move = genData.MoveData[moveName]
      continue  if !move
      if move.primaryBoostStats? && move.primaryBoostStats.evasion > 0 &&
          move.primaryBoostTarget == 'self'
        errors.push("#{prefix}: #{moveName} is banned under Evasion Clause.")

    return errors

createCondition Conditions.OHKO_CLAUSE,
  validatePokemon: (pokemon, genData, prefix) ->
    {moves} = pokemon
    errors = []

    # Check OHKO moves
    for moveName in moves || []
      move = genData.MoveData[moveName]
      continue  if !move
      if "ohko" in move.flags
        errors.push("#{prefix}: #{moveName} is banned under One-Hit KO Clause.")

    return errors

createCondition Conditions.UNRELEASED_BAN,
  validatePokemon: (pokemon, genData, prefix) ->
    # Check for unreleased items
    errors = []
    if pokemon.item && genData.ItemData[pokemon.item]?.unreleased
      errors.push("#{prefix}: The item '#{pokemon.item}' is unreleased.")
    # Check for unreleased abilities
    forme = genData.FormeData[pokemon.name][pokemon.forme || "default"]
    if forme.unreleasedHidden && pokemon.ability == forme.hiddenAbility &&
        forme.hiddenAbility not in forme.abilities
      errors.push("#{prefix}: The ability #{pokemon.ability} is unreleased.")
    # Check for unreleased Pokemon
    if forme.unreleased
      errors.push("#{prefix}: The Pokemon #{pokemon.name} is unreleased.")
    return errors

createCondition Conditions.RATED_BATTLE,
  attach:
    end: (winnerId) ->
      return  if !winnerId
      index = @getPlayerIndex(winnerId)
      loserId = @playerIds[1 - index]
      ratings = require './ratings'
      
      winner = @getPlayer(winnerId)
      loser = @getPlayer(loserId)

      winnerId = winner.ratingKey
      loserId = loser.ratingKey

      ratings.getRatings [ winnerId, loserId ], (err, oldRatings) =>
        ratings.updatePlayers winnerId, loserId, ratings.results.WIN, (err, result) =>
          return @message "An error occurred updating rankings :("  if err
          
          oldRating = Math.floor(oldRatings[0])
          newRating = Math.floor(result[0])
          @cannedText('RATING_UPDATE', index, oldRating, newRating)
          
          oldRating = Math.floor(oldRatings[1])
          newRating = Math.floor(result[1])
          @cannedText('RATING_UPDATE', 1 - index, oldRating, newRating)
          
          @emit('ratingsUpdated')
          @sendUpdates()

createCondition Conditions.TIMED_BATTLE,
  attach:
    initialize: ->
      previewTime = Date.now() + @TEAM_PREVIEW_TIMER
      check = () =>
        @startBattle()
        @sendUpdates()
      @teamPreviewTimerId = setTimeout(check, @TEAM_PREVIEW_TIMER)
      @once('end', => clearTimeout(@teamPreviewTimerId))
      @once('start', => clearTimeout(@teamPreviewTimerId))
      endTimes = (previewTime  for playerId in @playerIds)
      @tell(Protocol.UPDATE_TIMERS, endTimes...)

    start: ->
      nowTime = Date.now()
      @playerTimes = {}
      for id in @playerIds
        @playerTimes[id] = nowTime + @DEFAULT_TIMER
        # Remove first turn since we'll be increasing it again.
        @playerTimes[id] -= @TIMER_PER_TURN_INCREASE
      @lastActionTimes = {}
      @startTimer()

    requestActions: (playerId) ->
      # If a player has selected a move, then there's an amount of time spent
      # between move selection and requesting another action that was "lost".
      # We grant this back here.
      if @lastActionTimes[playerId]
        now = Date.now()
        leftoverTime = now - @lastActionTimes[playerId]
        delete @lastActionTimes[playerId]
        @addTime(playerId, leftoverTime)
      # In either case, we update timers and  tell people that this
      # player's timer resumes.
      endTimes = (@endTimeFor(id)  for id in @playerIds)
      @tell(Protocol.UPDATE_TIMERS, endTimes...)
      @tell(Protocol.RESUME_TIMER, @getPlayerIndex(playerId))

    addAction: (playerId, action) ->
      # Record the last action for use
      @lastActionTimes[playerId] = Date.now()
      @recalculateTimers()

    undoCompletedRequest: (playerId) ->
      delete @lastActionTimes[playerId]
      @recalculateTimers()

    # Show players updated times
    beginTurn: ->
      endTimes = []
      for id in @playerIds
        @addTime(id, @TIMER_PER_TURN_INCREASE)
        endTimes.push(@endTimeFor(id))
      @tell(Protocol.UPDATE_TIMERS, endTimes...)

    continueTurn: ->
      for id in @playerIds
        @tell(Protocol.PAUSE_TIMER, @getPlayerIndex(id))

  extend:
    DEFAULT_TIMER: 5 * 60 * 1000  # five minutes
    TIMER_PER_TURN_INCREASE: 20 * 1000  # twenty seconds
    TIMER_CAP: 5 * 60 * 1000  # five minutes
    TEAM_PREVIEW_TIMER: 1.5 * 60 * 1000  # 1 minute and 30 seconds

    startTimer: (msecs) ->
      msecs ?= @DEFAULT_TIMER
      @timerId = setTimeout(@declareWinner.bind(this), msecs)
      @once('end', => clearTimeout(@timerId))

    addTime: (id, msecs) ->
      @playerTimes[id] += msecs
      remainingTime = @timeRemainingFor(id)
      if remainingTime > @TIMER_CAP
        diff = remainingTime - @TIMER_CAP
        @playerTimes[id] -= diff
      @recalculateTimers()
      @playerTimes[id]

    recalculateTimers: ->
      playerTimes = for id in @playerIds
        if @lastActionTimes[id] then Infinity else @timeRemainingFor(id)
      leastTime = Math.min(playerTimes...)
      clearTimeout(@timerId)
      if 0 < leastTime < Infinity
        @timerId = setTimeout(@declareWinner.bind(this), leastTime)
      else if leastTime <= 0
        @declareWinner()

    timeRemainingFor: (playerId) ->
      endTime = @endTimeFor(playerId)
      nowTime = @lastActionTimes[playerId] || Date.now()
      return endTime - nowTime

    endTimeFor: (playerId) ->
      endTime = @playerTimes[playerId]
      endTime

    playersWithLeastTime: ->
      losingIds = []
      leastTimeRemaining = Infinity
      for id in @playerIds
        timeRemaining = @timeRemainingFor(id)
        if timeRemaining < leastTimeRemaining
          losingIds = [ id ]
          leastTimeRemaining = timeRemaining
        else if timeRemaining == leastTimeRemaining
          losingIds.push(id)
      return losingIds

    declareWinner: ->
      loserIds = @playersWithLeastTime()
      loserId = @rng.choice(loserIds, "timer")
      index = @getPlayerIndex(loserId)
      winnerIndex = 1 - index
      @timerWin(winnerIndex)

    timerWin: (winnerIndex) ->
      @tell(Protocol.TIMER_WIN, winnerIndex)
      @emit('end', @playerIds[winnerIndex])
      @sendUpdates()

createCondition Conditions.TEAM_PREVIEW,
  attach:
    initialize: ->
      @arranging = true
      @arranged = {}

    beforeStart: ->
      @tell(Protocol.TEAM_PREVIEW)

    start: ->
      @arranging = false
      arrangements = @getArrangements()
      @tell(Protocol.REARRANGE_TEAMS, arrangements...)
      for playerId, i in @playerIds
        team = @getTeam(playerId)
        team.arrange(arrangements[i])

  extendFacade:
    arrangeTeam: (playerId, arrangement) ->
      return false  if @battle.hasStarted()
      return false  if arrangement not instanceof Array
      team = @battle.getTeam(playerId)
      return false  if !team
      return false  if arrangement.length != team.size()
      for index, i in arrangement
        return false  if isNaN(index)
        return false  if !team.pokemon[index]
        return false  if arrangement.indexOf(index, i + 1) != -1
      @battle.arrangeTeam(playerId, arrangement)
      @battle.sendUpdates()
      return true

  extend:
    arrangeTeam: (playerId, arrangement) ->
      return false  unless @arranging
      @arranged[playerId] = arrangement
      if _.difference(@playerIds, Object.keys(@arranged)).length == 0
        @startBattle()

    getArrangements: ->
      for playerId in @playerIds
        @arranged[playerId] || [0...@getTeam(playerId).size()]
