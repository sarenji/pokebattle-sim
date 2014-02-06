{createHmac} = require 'crypto'
{_} = require 'underscore'

{BattleQueue} = require './queue'
{Conditions} = require './conditions'
{SocketHash} = require './socket_hash'
gen = require './generations'
learnsets = require '../shared/learnsets'
config = require './config'
errors = require '../shared/errors'

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

  registerChallenge: (player, challengeeId, generation, team, options) ->
    if !@users.contains(challengeeId)
      errorMessage = "This user is offline."
      player.error(errors.PRIVATE_MESSAGE, challengeeId, errorMessage)
      return false
    else if @challenges[player.id]?[challengeeId] ||
            @challenges[challengeeId]?[player.id]
      errorMessage = "A challenge already exists between you two."
      player.error(errors.PRIVATE_MESSAGE, challengeeId, errorMessage)
      return false

    # TODO: Validate generation

    err = @validateTeam(team, generation)
    if err.length > 0
      # TODO: Use a modal error instead
      player.error(errors.FIND_BATTLE, err)
      return false

    # TODO: Validate clauses
    @challenges[player.id] ?= {}
    @challenges[player.id][challengeeId] = {generation, team, options}
    @users.send(challengeeId, "challenge", player.id, generation, options)
    return true

  acceptChallenge: (player, challengerId, team) ->
    if !@challenges[challengerId]?[player.id]?
      errorMessage = "The challenge no longer exists."
      player.error(errors.PRIVATE_MESSAGE, challengerId, errorMessage)
      return false

    challenge = @challenges[challengerId][player.id]
    err = @validateTeam(team, challenge.generation)
    if err.length > 0
      # TODO: Use a modal error instead
      player.error(errors.FIND_BATTLE, err)
      return false

    teams = {}
    teams[challengerId] = challenge.team
    teams[player.id] = team

    # TODO: Use challenge.options
    options =
      conditions: [
        Conditions.TEAM_PREVIEW
        Conditions.SLEEP_CLAUSE
      ]
    @createBattle(challenge.generation, teams, options)
    @users.send(player.id, "challengeSuccess", challengerId)
    @users.send(challengerId, "challengeSuccess", player.id)
    delete @challenges[challengerId][player.id]
    return true

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
    return false  if generation not of @queues
    @queues[generation].add(playerId, team)
    return true

  queuedPlayers: (generation = gen.DEFAULT_GENERATION) ->
    @queues[generation].queuedPlayers()

  removePlayer: (playerId, generation = gen.DEFAULT_GENERATION) ->
    return false  if generation not of @queues
    @queues[generation].remove(playerId)
    return true

  beginBattles: (next) ->
    options =
      conditions: [
        Conditions.TEAM_PREVIEW
        Conditions.SLEEP_CLAUSE
        Conditions.RATED_BATTLE
      ]
    for generation in gen.SUPPORTED_GENERATIONS
      @queues[generation].pairPlayers (err, pairs) =>
        if err then return next(err)

        # Create a battle for each pair
        battleIds = []
        for pair in pairs
          id = @createBattle(generation, pair, options)
          battleIds.push(id)
        next(null, battleIds)  if battleIds.length > 0  # Skip blank generations
    return true

  # Creates a battle and returns its battleId
  createBattle: (generation = gen.DEFAULT_GENERATION, pair = {}, options = {}) ->
    {Battle} = require("../server/#{generation}/battle")
    {BattleController} = require("../server/#{generation}/battle_controller")
    playerIds = Object.keys(pair)
    battleId = @generateBattleId(playerIds)
    options = _.clone(options)
    options.players = pair
    battle = new Battle(battleId, options)
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

  removeUserBattle: (userId, battleId) ->
    delete @userBattles[userId][battleId]

  # Returns an empty array if the given team is valid, an array of errors
  # otherwise.
  validateTeam: (team, generation = gen.DEFAULT_GENERATION) ->
    return [ "Invalid team format." ]  if team not instanceof Array
    return [ "Team must have 1 to 6 Pokemon." ]  unless 1 <= team.length <= 6
    return team.map((pokemon, i) => @validatePokemon(pokemon, i + 1, generation)).flatten()

  # Returns an empty array if the given Pokemon is valid, an array of errors
  # otherwise.
  validatePokemon: (pokemon, slot, generation = gen.DEFAULT_GENERATION) ->
    {SpeciesData, FormeData} = gen.GenerationJSON[generation.toUpperCase()]
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
