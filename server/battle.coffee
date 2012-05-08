{_} = require 'underscore'
require 'js-yaml'
{FakeRNG} = require './rng'
{Pokemon} = require './pokemon'

class @Battle
  # TODO: let Battle serialize these.
  {moves, MoveData, PokemonData} = require '../data/bw'
  @pokemon = PokemonData

  constructor: (attributes = {}) ->
    {@players} = attributes

    # Stores the current turn of the battle
    @turn = 0

    # Stores the actions each player is about to make
    # Keyed by player.clientId
    @playerActions = {}

    # Creates a RNG for this battle.
    @rng = new FakeRNG()

    # Maps clientId -> object
    @objectHash = {}

    for object in @players
      @objectHash[object.player.clientId] = object

      # Each object is a hash: {player: socket, team: team}
      # TODO: Make this nicer.
      # Store an "opponents" array for each player. This array contains
      # all players except the current player.
      # This assumes a FFA.
      {player, team} = object
      object.opponents = _.reject @players, (object) ->
        object.player == player

      # Turn every hash in a team into a real, live Pokemon.
      object.team = team.map (attributes) ->
        new Pokemon(attributes)

  getPlayer: (clientId) =>
    @objectHash[clientId].player

  getTeam: (clientId) =>
    if !@objectHash[clientId]?
      console.log clientId
    @objectHash[clientId].team

  getOpponents: (clientId) =>
    @objectHash[clientId].opponents

  getAction: (clientId) =>
    @playerActions[clientId]

  makeMove: (player, moveName) =>
    moveName = moveName.toLowerCase()
    # TODO: Fail if move not in moves
    return  if moveName not of MoveData

    # Store the move name that this player wants to make.
    @playerActions[player.clientId] =
      type: 'move'
      name: moveName

    # End the turn if each player has moved.
    if @hasAllPlayersActed() then @endTurn()

  switch: (player, toPosition) =>
    # Record the switch
    @playerActions[player.clientId] =
      type: 'switch'
      to: toPosition

    # End the turn if each player has moved.
    if @hasAllPlayersActed() then @endTurn()

  # Returns true if all players have moved, false otherwise.
  hasAllPlayersActed: =>
    _.all(@players, (object) => object.player.clientId of @playerActions)

  endTurn: =>
    # Act on player actions.
    # TODO: Sort by priority and active pokemon speed.
    for clientId of @playerActions
      action = @getAction(clientId)
      # TODO: abstract better?
      switch action.type
        when 'switch'
          team = @getTeam(clientId)
          [team[0], team[action.to]] = [team[action.to], team[0]]
        when 'move'
          player = @getPlayer(clientId)
          pokemon = @getTeam(clientId)[0]
          # TODO: Make this nicer.
          for opponent in @getOpponents(clientId)
            # todo: the move should be cloned and attached to the pokemon
            defender = @getTeam(opponent.player.clientId)[0]

            # Any before move events
            moves[action.name].execute(this, pokemon, defender)
            # Any after move events

          # TODO: Apply multi-target and weather modifiers
          # TODO: Apply random factor
          # TODO: Apply STAB
          # TODO: Apply type-effectiveness
          # TODO: Apply burn

      # Clean up playerActions hash.
      delete @playerActions[clientId]

    # Send a message to each player about the end of turn.
    for object in @players
      object.player.emit? 'updatechat', 'SERVER', 'end turn!'

  baseDamage: (attacker, defender, move) =>
    baseDamage = Math.floor((2 * attacker.level) / 5 + 2)
    # TODO: Apply variable base power
    baseDamage *= move.power
    # TODO: Differentiate between attack and special attack
    # TODO: Apply boosts to stat
    baseDamage *= attacker.stat('attack')
    baseDamage = Math.floor(baseDamage / defender.stat('defense'))
    baseDamage += 2

  damage: (attacker, defender, damage) =>
    defender.currentHP -= damage
