{createHmac} = require 'crypto'
{_} = require 'underscore'

{User} = require('./user')
{BattleQueue} = require './queue'
{SocketHash} = require './socket_hash'
gen = require './generations'
auth = require('./auth')
learnsets = require '../shared/learnsets'
{Conditions} = require '../shared/conditions'
pbv = require '../shared/pokebattle_values'
config = require './config'
errors = require '../shared/errors'

FIND_BATTLE_CONDITIONS = [
  Conditions.TEAM_PREVIEW
  Conditions.RATED_BATTLE
  Conditions.PBV_1000
  Conditions.TIMED_BATTLE
  Conditions.SLEEP_CLAUSE
  Conditions.EVASION_CLAUSE
  Conditions.SPECIES_CLAUSE
  Conditions.OHKO_CLAUSE
  Conditions.UNRELEASED_BAN
]

class @BattleServer
  constructor: ->
    @queues = {}
    for generation in gen.SUPPORTED_GENERATIONS
      @queues[generation] = new BattleQueue()
    @battles = {}

    # A hash mapping users to battles.
    @userBattles = {}

    # A hash mapping user ids to challenges
    # challenges[challengeeId][challengerId] = {generation: 'xy', team: []}
    @challenges = {}

    # A hash mapping ids to users
    @users = new SocketHash()

    @rooms = []

    # Battles can start.
    @unlockdown()

  join: (player) ->
    @users.add(player)
    for battleId of @userBattles[player.id]
      battle = @battles[battleId]
      battle.addSpectator(player)
      battle.sendRequestTo(player.id)
      battle.sendUpdates()

  leave: (player) ->
    if @users.remove(player) == 0
      @stopChallenges(player)

  registerChallenge: (player, challengeeId, generation, team, conditions) ->
    if @isLockedDown()
      errorMessage = "The server is locked. No new battles can start at this time."
      player.error(errors.PRIVATE_MESSAGE, challengeeId, errorMessage)
      return false
    else if !@users.contains(challengeeId)
      errorMessage = "This user is offline."
      player.error(errors.PRIVATE_MESSAGE, challengeeId, errorMessage)
      return false
    else if player.id == challengeeId
      errorMessage = "You cannot challenge yourself."
      player.error(errors.PRIVATE_MESSAGE, challengeeId, errorMessage)
      return false
    else if @challenges[player.id]?[challengeeId] ||
            @challenges[challengeeId]?[player.id]
      errorMessage = "A challenge already exists between you two."
      player.error(errors.PRIVATE_MESSAGE, challengeeId, errorMessage)
      return false

    err = @validateTeam(team, generation, conditions)
    if err.length > 0
      # TODO: Use a modal error instead
      player.error(errors.FIND_BATTLE, err)
      return false

    @challenges[player.id] ?= {}
    @challenges[player.id][challengeeId] = {generation, team, conditions}
    @users.send(challengeeId, "challenge", player.id, generation, conditions)
    return true

  acceptChallenge: (player, challengerId, team) ->
    if !@challenges[challengerId]?[player.id]?
      errorMessage = "The challenge no longer exists."
      player.error(errors.PRIVATE_MESSAGE, challengerId, errorMessage)
      return null

    challenge = @challenges[challengerId][player.id]
    err = @validateTeam(team, challenge.generation, challenge.conditions)
    if err.length > 0
      # TODO: Use a modal error instead
      player.error(errors.FIND_BATTLE, err)
      return null

    teams = {}
    teams[challengerId] = challenge.team
    teams[player.id] = team

    id = @createBattle(challenge.generation, teams, challenge.conditions)
    @users.send(player.id, "challengeSuccess", challengerId)
    @users.send(challengerId, "challengeSuccess", player.id)
    delete @challenges[challengerId][player.id]
    return id

  rejectChallenge: (player, challengerId) ->
    if !@challenges[challengerId]?[player.id]?
      errorMessage = "The challenge no longer exists."
      player.error(errors.PRIVATE_MESSAGE, challengerId, errorMessage)
      return false
    delete @challenges[challengerId][player.id]
    @users.send(player.id, "rejectChallenge", challengerId)
    @users.send(challengerId, "rejectChallenge", player.id)

  cancelChallenge: (player, challengeeId) ->
    if !@challenges[player.id]?[challengeeId]?
      errorMessage = "The challenge no longer exists."
      player.error(errors.PRIVATE_MESSAGE, challengeeId, errorMessage)
      return false
    delete @challenges[player.id][challengeeId]
    @users.send(player.id, "cancelChallenge", challengeeId)
    @users.send(challengeeId, "cancelChallenge", player.id)

  stopChallenges: (player) ->
    playerId = player.id
    for challengeeId of @challenges[playerId]
      @cancelChallenge(player, challengeeId)
    delete @challenges[playerId]
    for challengerId of @challenges
      if @challenges[challengerId][playerId]
        @rejectChallenge(player, challengerId)

  queuePlayer: (playerId, team, generation = gen.DEFAULT_GENERATION) ->
    if @isLockedDown()
      return ["The server is locked. No new battles can start at this time."]
    else
      err = @validateTeam(team, generation, FIND_BATTLE_CONDITIONS)
      @queues[generation].add(playerId, team)  if err.length == 0
      return err

  queuedPlayers: (generation = gen.DEFAULT_GENERATION) ->
    @queues[generation].queuedPlayers()

  removePlayer: (playerId, generation = gen.DEFAULT_GENERATION) ->
    return false  if generation not of @queues
    @queues[generation].remove(playerId)
    return true

  beginBattles: (next) ->
    for generation in gen.SUPPORTED_GENERATIONS
      @queues[generation].pairPlayers (err, pairs) =>
        if err then return next(err)

        # Create a battle for each pair
        battleIds = []
        for pair in pairs
          id = @createBattle(generation, pair, FIND_BATTLE_CONDITIONS)
          battleIds.push(id)
        next(null, battleIds)  if battleIds.length > 0  # Skip blank generations
    return true

  # Creates a battle and returns its battleId
  createBattle: (generation = gen.DEFAULT_GENERATION, pair = {}, conditions = []) ->
    {Battle} = require("../server/#{generation}/battle")
    {BattleController} = require("../server/#{generation}/battle_controller")
    playerIds = Object.keys(pair)
    battleId = @generateBattleId(playerIds)
    battle = new Battle(battleId, pair, conditions: _.clone(conditions))
    @battles[battleId] = new BattleController(battle)
    for playerId in playerIds
      # Add users to spectators
      @users.iterate playerId, (user) ->
        battle.addSpectator(user)

      # Add/remove player ids to/from user battles
      @userBattles[playerId] ?= {}
      @userBattles[playerId][battleId] = true
      battle.on 'end', @removeUserBattle.bind(this, playerId, battleId)
    @battles[battleId].beginBattle()
    battleId

  # Generate a random ID for a new battle.
  generateBattleId: (players) ->
    hmac = createHmac('sha1', config.SECRET_KEY)
    hmac.update((new Date).toISOString())
    for id in players
      hmac.update(id)
    hmac.digest('hex')

  # Returns the battle with battleId.
  findBattle: (battleId) ->
    @battles[battleId]

  getUserBattles: (userId) ->
    (id  for id, value of @userBattles[userId])

  getOngoingBattles: ->
    # TODO: This is very inefficient. Improve this.
    _.chain(@battles).values().reject((b) -> b.battle.isOver()).value()

  removeUserBattle: (userId, battleId) ->
    delete @userBattles[userId][battleId]

  # A length of -1 denotes a permanent ban.
  ban: (username, reason, length = -1) ->
    auth.ban(username, reason, length)
    @users.error(username, errors.BANNED, reason, length)
    @users.close(username)

  unban: (username, next) ->
    auth.unban(username, next)

  mute: (username, reason, length) ->
    auth.mute(username, reason, length)

  unmute: (username) ->
    auth.unmute(username)

  announce: (message) ->
    rawMessage = """<div class="alert alert-warning">#{message}</div>"""
    for room in @rooms
      room.message(rawMessage)
    for battleId, battle of @battles
      battle.rawMessage(rawMessage)

  userMessage: (room, user, message) ->
    auth.getMuteTTL user.id, (err, ttl) ->
      if ttl == -2
        room.userMessage(user, message)
      else
        # is muted

  setAuthority: (user, newAuthority) ->
    if user instanceof User
      user.authority = newAuthority
    else
      for user in @users.get(user)
        user.authority = newAuthority

  lockdown: ->
    @canBattlesStart = false
    for user in @users.values()
      @stopChallenges(user)
    @announce("<strong>The server is locked!</strong> No new battles can start at this time.")

  unlockdown: ->
    @canBattlesStart = true
    @announce("<strong>The server was unlocked!</strong> You may battle again.")

  isLockedDown: ->
    !@canBattlesStart

  # Returns an empty array if the given team is valid, an array of errors
  # otherwise.
  validateTeam: (team, generation = gen.DEFAULT_GENERATION, conditions = []) ->
    return [ "Invalid team format." ]  if team not instanceof Array
    return [ "Team must have 1 to 6 Pokemon." ]  unless 1 <= team.length <= 6
    if generation not in gen.SUPPORTED_GENERATIONS
      return [ "Invalid generation: #{generation}." ]
    genData = gen.GenerationJSON[generation.toUpperCase()]

    err = require('./conditions').validateTeam(conditions, team, genData)
    return err  if err.length > 0

    err = team.map (pokemon, i) =>
      @validatePokemon(conditions, pokemon, i + 1, generation)
    return err.flatten()

  # Returns an empty array if the given Pokemon is valid, an array of errors
  # otherwise.
  validatePokemon: (conditions, pokemon, slot, generation = gen.DEFAULT_GENERATION) ->
    genData = gen.GenerationJSON[generation.toUpperCase()]
    {SpeciesData, FormeData} = genData
    err = []
    prefix = "Slot ##{slot}"

    if !pokemon.name
      err.push("#{prefix}: No species given.")
      return err
    species = SpeciesData[pokemon.name]
    if !species
      err.push("#{prefix}: Invalid species: #{pokemon.name}.")
      return err

    prefix += " (#{pokemon.name})"
    @normalizePokemon(pokemon, generation)
    forme = FormeData[pokemon.name][pokemon.forme]
    if !forme
      err.push("#{prefix}: Invalid forme: #{pokemon.forme}.")
      return err

    if forme.isBattleOnly
      err.push("#{prefix}: #{pokemon.forme} forme is battle-only.")
      return err

    if isNaN(pokemon.level)
      err.push("#{prefix}: Invalid level: #{pokemon.level}.")
    # TODO: 100 is a magic constant
    else if !(1 <= pokemon.level <= 100)
      err.push("#{prefix}: Level must be between 1 and 100.")

    if pokemon.gender not in [ "M", "F", "Genderless" ]
      err.push("#{prefix}: Invalid gender: #{pokemon.gender}.")
    if species.genderRatio == -1 && pokemon.gender != "Genderless"
      err.push("#{prefix}: Must be genderless.")
    if species.genderRatio == 0 && pokemon.gender != "M"
      err.push("#{prefix}: Must be male.")
    if species.genderRatio == 8 && pokemon.gender != "F"
      err.push("#{prefix}: Must be female.")
    if (typeof pokemon.evs != "object")
      err.push("#{prefix}: Invalid evs.")
    if (typeof pokemon.ivs != "object")
      err.push("#{prefix}: Invalid ivs.")
    if !Object.values(pokemon.evs).all((ev) -> 0 <= ev <= 255)
      err.push("#{prefix}: EVs must be between 0 and 255.")
    if !Object.values(pokemon.ivs).all((iv) -> 0 <= iv <= 31)
      err.push("#{prefix}: IVs must be between 0 and 31.")
    if pokemon.ability not in forme["abilities"] &&
       pokemon.ability != forme["hiddenAbility"]
      err.push("#{prefix}: Invalid ability.")
    if pokemon.moves not instanceof Array
      err.push("#{prefix}: Invalid moves.")
    # TODO: 4 is a magic constant
    else if !(1 <= pokemon.moves.length <= 4)
      err.push("#{prefix}: Must have 1 to 4 moves.")
    else if !learnsets.checkMoveset(gen.GenerationJSON, pokemon,
                        gen.GENERATION_TO_INT[generation], pokemon.moves)
      err.push("#{prefix}: Invalid moveset.")
    err.push require('./conditions').validatePokemon(conditions, pokemon, genData, prefix)...
    return err

  # Normalizes a Pokemon by setting default values where applicable.
  # Assumes that the Pokemon is a real Pokemon (i.e. its name is valid)
  normalizePokemon: (pokemon, generation = gen.DEFAULT_GENERATION) ->
    {SpeciesData, FormeData} = gen.GenerationJSON[generation.toUpperCase()]
    pokemon.forme   ?= "default"
    pokemon.ability ?= FormeData[pokemon.name][pokemon.forme]?["abilities"][0]
    if !pokemon.gender?
      {genderRatio} = SpeciesData[pokemon.name]
      if genderRatio == -1 then pokemon.gender = "Genderless"
      else if Math.random() < (genderRatio / 8) then pokemon.gender = "F"
      else pokemon.gender = "M"
    pokemon.evs     ?= {}
    pokemon.ivs     ?= {}
    pokemon.level   ?= 100
    pokemon.level    = Math.floor(pokemon.level)
    return pokemon
