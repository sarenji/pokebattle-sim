{createHmac} = require 'crypto'
{_} = require 'underscore'

{BattleQueue} = require './queue'
{Battle} = require './battle'
{BattleController} = require './battle_controller'
learnsets = require '../shared/learnsets'

class @BattleServer
  constructor: ->
    @queue = new BattleQueue()
    @battles = {}

  queuePlayer: (player, team) ->
    @queue.add(player, team)

  queuedPlayers: ->
    @queue.queuedPlayers()

  beginBattles: ->
    pairs = @queue.pairPlayers()
    battles = []

    # Create a battle for each pair
    for pair in pairs
      id = @createBattle(pair...)
      @beginBattle(id)
      battle = pair.map((o) -> o.player)
      battle.push(id)
      battles.push(battle)

    battles

  # Creates a battle and returns its battleId
  createBattle: (objects...) ->
    players = objects.map (object) -> object.player
    battleId = @generateBattleId(players)
    @battles[battleId] = new BattleController(new Battle(battleId, players: objects))
    battleId

  beginBattle: (battleId) ->
    @battles[battleId].beginBattle()

  # Generate a random ID for a new battle.
  generateBattleId: (players) ->
    # TODO load key from config or env
    hmac = createHmac('sha1', 'INSECURE KEY')
    hmac.update((new Date).toISOString())
    for player in players
      hmac.update(player.id)
    hmac.digest('hex')

  # Returns the battle with battleId.
  findBattle: (battleId) ->
    @battles[battleId]

  # Returns true if the given team is valid, false otherwise.
  validateTeam: (team) ->
    return false  if team not instanceof Array
    return false  if team.length == 0
    return team.all((pokemon) => @validatePokemon(pokemon))

  # Returns true if the given Pokemon is valid, false otherwise.
  validatePokemon: (pokemon) ->
    {SpeciesData, FormeData} = Battle
    return false  if !pokemon.name
    species = SpeciesData[pokemon.name]
    return false  if !species

    @normalizePokemon(pokemon)
    forme = FormeData[pokemon.name][pokemon.forme]
    return false  if !forme
    return false  if isNaN(pokemon.level)
    # TODO: 100 is a magic constant
    return false  unless 1 <= pokemon.level <= 100
    return false  if pokemon.gender not in [ "M", "F", "Genderless" ]
    return false  if (species.genderRatio == -1 && pokemon.gender != "Genderless") ||
                     (species.genderRatio == 0 && pokemon.gender != "M") ||
                     (species.genderRatio == 8 && pokemon.gender != "F")
    return false  if (typeof pokemon.evs != "object")
    return false  if (typeof pokemon.ivs != "object")
    return false  if !Object.values(pokemon.evs).all((ev) -> 0 <= ev <= 255)
    return false  if !Object.values(pokemon.ivs).all((iv) -> 0 <= iv <= 31)
    return false  if pokemon.ability not in forme["abilities"] &&
                     pokemon.ability != forme["hiddenAbility"]
    return false  if pokemon.moves not instanceof Array
    # TODO: 4 is a magic constant
    return false  unless 1 <= pokemon.moves.length <= 4
    return false  if !learnsets.checkMoveset(SpeciesData, FormeData, pokemon, 5, pokemon.moves)
    return true

  # Normalizes a Pokemon by setting default values where applicable.
  # Assumes that the Pokemon is a real Pokemon (i.e. its name is valid)
  normalizePokemon: (pokemon) ->
    pokemon.forme   ?= "default"
    pokemon.ability ?= Battle.FormeData[pokemon.name][pokemon.forme]?["abilities"][0]
    if !pokemon.gender?
      {genderRatio} = Battle.SpeciesData[pokemon.name]
      if genderRatio == -1 then pokemon.gender = "Genderless"
      else if Math.random() < (genderRatio / 8) then pokemon.gender = "F"
      else pokemon.gender = "M"
    pokemon.evs     ?= {}
    pokemon.ivs     ?= {}
    pokemon.level   ?= 100
    pokemon.level    = Math.floor(pokemon.level)
    return pokemon
