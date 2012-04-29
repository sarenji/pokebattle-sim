{_} = require 'underscore'
require 'js-yaml'
{FakeRNG} = require './rng'
{Pokemon} = require './pokemon'

class @Battle
  # TODO: let Battle serialize these.
  @moves = MoveData = require('../data/rb/moves.yml').pop()
  @pokemon = PokemonData = require('../data/bw/pokemon.yml').pop()

  constructor: (attributes = {}) ->
    {@players} = attributes

    for player in @players
      # TODO: Make this nicer.
      # Store an "opponents" array for each player. This array contains
      # all players except the current player.
      # This assumes a FFA.
      player.opponents = _.reject(@players, (opponent) -> opponent == player)

      # Turn every hash in a team into a real, live Pokemon.
      player.team = player.team.map (attributes) ->
        new Pokemon(attributes)

    # Stores the current turn of the battle
    @turn = 0

    # Stores the moves each player is about to make
    @playerMoves = {}

    # Creates a RNG for this battle.
    @rng = new FakeRNG()

    # Maps clientId -> player
    @playerHash = {}
    for player in @players
      @playerHash[player.clientId] = player

  makeMove: (player, moveName) =>
    moveName = moveName.toLowerCase()
    # TODO: Fail if move not in moves
    return  if moveName not of MoveData

    # Store the move name that this player wants to make.
    @playerMoves[player.clientId] =
      type: 'move'
      name: moveName

    # End the turn if each player has moved.
    if @hasAllPlayersMoved() then @endTurn()

  switch: (player, toPosition) =>
    # Record the switch
    @playerMoves[player.clientId] =
      type: 'switch'
      to: toPosition

    # End the turn if each player has moved.
    if @hasAllPlayersMoved() then @endTurn()

  # Returns true if all players have moved, false otherwise.
  hasAllPlayersMoved: =>
    _.all(@players, (player) => player.clientId of @playerMoves)

  endTurn: =>
    # Act on player actions.
    # TODO: Sort by priority and active pokemon speed.
    for clientId of @playerMoves
      move = @playerMoves[clientId]
      # TODO: abstract better?
      switch move.type
        when 'switch'
          {team} = @playerHash[clientId]
          {to} = move
          [team[0], team[to]] = [team[to], team[0]]
        when 'move'
          player = @playerHash[clientId]
          pokemon = player.team[0]
          # TODO: Make this nicer.
          for opponent in player.opponents
            defender = opponent.team[0]
            baseDamage = @baseDamage(pokemon, defender, MoveData[move.name])
            @damage(pokemon, defender, baseDamage)

          # TODO: Apply multi-target and weather modifiers
          # TODO: Apply random factor
          # TODO: Apply STAB
          # TODO: Apply type-effectiveness
          # TODO: Apply burn


      # Clean up playerMoves hash.
      delete @playerMoves[clientId]

    # Send a message to each player about the end of turn.
    for player in @players
      player.emit? 'updatechat', 'SERVER', 'end turn!'

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
