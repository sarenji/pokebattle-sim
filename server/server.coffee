{createHmac} = require 'crypto'
{_} = require 'underscore'

{User} = require('./user')
{BattleQueue} = require './queue'
{SocketHash} = require './socket_hash'
async = require('async')
gen = require './generations'
auth = require('./auth')
learnsets = require '../shared/learnsets'
{Conditions} = require '../shared/conditions'
pbv = require '../shared/pokebattle_values'
config = require './config'
errors = require '../shared/errors'
redis = require('./redis')
alts = require './alts'

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

    # same as user battles, but indexed by name and does not include alts
    @visibleUserBattles = {}

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
    @showTopic(player)
    for battleId of @userBattles[player.id]
      battle = @battles[battleId]
      battle.addSpectator(player)
      battle.sendRequestTo(player.id)
      battle.sendUpdates()

  showTopic: (player) ->
    redis.hget "topic", "main", (err, topic) ->
      player.send('topic', topic)  if topic

  leave: (player) ->
    if @users.remove(player) == 0
      @stopChallenges(player)
      for battleId of @userBattles[player.id]
        battle = @battles[battleId]
        battle.removeSpectator(player)

  registerChallenge: (player, challengeeId, generation, team, conditions, altName) ->
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

    # Do not allow rated battles.
    if _.find(conditions, (c) -> c == Conditions.RATED_BATTLE)
      player.error(errors.FIND_BATTLE, 'You cannot issue a rated challenge.')
      return false

    err = @validateTeam(team, generation, conditions)
    if err.length > 0
      # TODO: Use a modal error instead
      player.error(errors.FIND_BATTLE, err)
      return false

    @challenges[player.id] ?= {}
    @challenges[player.id][challengeeId] = {generation, team, conditions, challengerName: player.name, altName}
    @users.send(challengeeId, "challenge", player.id, generation, conditions)
    return true

  acceptChallenge: (player, challengerId, team, altName) ->
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

    teams = [
      {
        id: challengerId,
        name: challenge.altName || challenge.challengerName,
        team: challenge.team,
        ratingKey: alts.uniqueId(challengerId, challenge.altName)
      }
      {
        id: player.id,
        name: altName || player.name,
        team: team,
        ratingKey: alts.uniqueId(player.id, altName)
      }
    ]

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

  # Adds the player to the queue. Note that there is no validation on whether altName
  # is correct, so make 
  queuePlayer: (playerId, team, generation = gen.DEFAULT_GENERATION, altName) ->
    if @isLockedDown()
      err = ["The server is locked. No new battles can start at this time."]
    else
      err = @validateTeam(team, generation, FIND_BATTLE_CONDITIONS)
      if err.length == 0
        name = @users.get(playerId)[0]?.name
        ratingKey = alts.uniqueId(playerId, altName)
        @queues[generation].add(playerId, altName || name, team, ratingKey)
      return err

  queuedPlayers: (generation = gen.DEFAULT_GENERATION) ->
    @queues[generation].queuedPlayers()

  removePlayer: (playerId, generation = gen.DEFAULT_GENERATION) ->
    return false  if generation not of @queues
    @queues[generation].remove(playerId)
    return true

  beginBattles: (next) ->
    array = for generation in gen.SUPPORTED_GENERATIONS
      do (generation) => (callback) =>
        @queues[generation].pairPlayers (err, pairs) =>
          if err then return callback(err)

          # Create a battle for each pair
          battleIds = []
          for pair in pairs
            id = @createBattle(generation, pair, FIND_BATTLE_CONDITIONS)
            battleIds.push(id)
          callback(null, battleIds)
    async.parallel array, (err, battleIds) ->
      return next(err)  if err
      next(null, _.flatten(battleIds))
    return true

  # Creates a battle and returns its battleId
  createBattle: (generation = gen.DEFAULT_GENERATION, pair = [], conditions = []) ->
    {Battle} = require("../server/#{generation}/battle")
    {BattleController} = require("../server/#{generation}/battle_controller")
    playerIds = pair.map((user) -> user.id)
    battleId = @generateBattleId(playerIds)
    battle = new Battle(battleId, pair, conditions: _.clone(conditions))
    @battles[battleId] = new BattleController(battle)
    for player in pair
      # Add users to spectators
      @users.iterate player.id, (user) ->
        battle.addSpectator(user)

      # Add/remove player ids to/from user battles
      @userBattles[player.id] ?= {}
      @userBattles[player.id][battleId] = true
      
      # Add the player to the list if its not an alt
      if player.id == player.ratingKey  # hacky - but no alternative right now
        @visibleUserBattles[player.name] ?= {}
        @visibleUserBattles[player.name][battleId] = true
      
      battle.on 'end', @removeUserBattle.bind(this, player.id, player.name, battleId)
    
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

  # Returns all non-alt battles the user is playing in
  getVisibleUserBattles: (username) ->
    (id  for id, value of @visibleUserBattles[username])

  getOngoingBattles: ->
    # TODO: This is very inefficient. Improve this.
    _.chain(@battles).values().reject((b) -> b.battle.isOver()).value()

  removeUserBattle: (userId, username, battleId) ->
    delete @userBattles[userId][battleId]
    delete @visibleUserBattles[username]?[battleId]

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
        user.message("You are muted for another #{ttl} seconds!")

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
    @announce("<strong>The server is restarting!</strong> All battles are locked: No new battles may start at this time.")

  unlockdown: ->
    @canBattlesStart = true
    @announce("<strong>Battles have been unlocked!</strong> You may battle again.")

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
    if Object.values(pokemon.evs).reduce(((x, y) -> x + y), 0) > 510
      err.push("#{prefix}: EV total must be less than 510.")
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
