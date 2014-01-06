{createHmac} = require 'crypto'
{_} = require 'underscore'

{BattleQueue} = require './queue'
{Conditions} = require './conditions'
gen = require './generations'
learnsets = require '../shared/learnsets'
config = require './config'

class @BattleServer
  constructor: ->
    @queues = {}
    for generation in gen.SUPPORTED_GENERATIONS
      @queues[generation] = new BattleQueue()
    @battles = {}

    # A hash mapping users to battles.
    @userBattles = {}

  queuePlayer: (player, team, generation = gen.DEFAULT_GENERATION) ->
    return false  if generation not of @queues
    @queues[generation].add(player, team)
    return true

  queuedPlayers: (generation = gen.DEFAULT_GENERATION) ->
    @queues[generation].queuedPlayers()

  removePlayer: (player, generation = gen.DEFAULT_GENERATION) ->
    return false  if generation not of @queues
    @queues[generation].remove(player)
    return true

  beginBattles: (next) ->
    for generation in gen.SUPPORTED_GENERATIONS
      @queues[generation].pairPlayers (err, pairs) =>
        if err then return next(err)

        # Create a battle for each pair
        battleIds = []
        for pair in pairs
          id = @createBattle(generation, pair...)
          @beginBattle(id)
          battleIds.push(id)
        next(null, battleIds)
    return true

  # Creates a battle and returns its battleId
  createBattle: (generation = gen.DEFAULT_GENERATION, objects...) ->
    {Battle} = require("../server/#{generation}/battle")
    {BattleController} = require("../server/#{generation}/battle_controller")
    playerIds = objects.map((o) -> o.player.id)
    battleId = @generateBattleId(playerIds)
    conditions = [ Conditions.TEAM_PREVIEW, Conditions.SLEEP_CLAUSE ]
    battle = new Battle(battleId, players: objects, conditions: conditions)
    @battles[battleId] = new BattleController(battle)
    for playerId in playerIds
      @userBattles[playerId] ?= {}
      @userBattles[playerId][battleId] = true
      battle.on 'end', @removeUserBattle.bind(this, playerId, battleId)
    battleId

  beginBattle: (battleId) ->
    @battles[battleId].beginBattle()

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
    errors = []
    prefix = "Slot ##{slot}"

    if !pokemon.name
      errors.push("#{prefix}: No species given.")
      return errors
    species = SpeciesData[pokemon.name]
    if !species
      errors.push("#{prefix}: Invalid species: #{pokemon.name}.")
      return errors

    prefix += " (#{pokemon.name})"
    @normalizePokemon(pokemon, generation)
    forme = FormeData[pokemon.name][pokemon.forme]
    if !forme
      errors.push("#{prefix}: Invalid forme: #{pokemon.forme}.")
      return errors

    if isNaN(pokemon.level)
      errors.push("#{prefix}: Invalid level: #{pokemon.level}.")
    # TODO: 100 is a magic constant
    else if !(1 <= pokemon.level <= 100)
      errors.push("#{prefix}: Level must be between 1 and 100.")

    if pokemon.gender not in [ "M", "F", "Genderless" ]
      errors.push("#{prefix}: Invalid gender: #{pokemon.gender}.")
    if species.genderRatio == -1 && pokemon.gender != "Genderless"
      errors.push("#{prefix}: Must be genderless.")
    if species.genderRatio == 0 && pokemon.gender != "M"
      errors.push("#{prefix}: Must be male.")
    if species.genderRatio == 8 && pokemon.gender != "F"
      errors.push("#{prefix}: Must be female.")
    if (typeof pokemon.evs != "object")
      errors.push("#{prefix}: Invalid evs.")
    if (typeof pokemon.ivs != "object")
      errors.push("#{prefix}: Invalid ivs.")
    if !Object.values(pokemon.evs).all((ev) -> 0 <= ev <= 255)
      errors.push("#{prefix}: EVs must be between 0 and 255.")
    if !Object.values(pokemon.ivs).all((iv) -> 0 <= iv <= 31)
      errors.push("#{prefix}: IVs must be between 0 and 31.")
    if pokemon.ability not in forme["abilities"] &&
       pokemon.ability != forme["hiddenAbility"]
      errors.push("#{prefix}: Invalid ability.")
    if pokemon.moves not instanceof Array
      errors.push("#{prefix}: Invalid moves.")
    # TODO: 4 is a magic constant
    else if !(1 <= pokemon.moves.length <= 4)
      errors.push("#{prefix}: Must have 1 to 4 moves.")
    else if !learnsets.checkMoveset(gen.GenerationJSON, pokemon,
                        gen.GENERATION_TO_INT[generation], pokemon.moves)
      errors.push("#{prefix}: Invalid moveset.")
    return errors

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
