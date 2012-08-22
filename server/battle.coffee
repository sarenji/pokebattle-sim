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
    # Keyed by player.id
    @playerActions = {}

    # Creates a RNG for this battle.
    @rng = new FakeRNG()

    # Maps clientId -> object
    @objectHash = {}

    for object in @players
      @objectHash[object.player.id] = object

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
    # TODO: Fail if move not in player pokemon's moves
    return  if moveName not of MoveData

    # Store the move name that this player wants to make.
    @playerActions[player.id] =
      type: 'move'
      name: moveName

    # End the turn if each player has moved.
    if @hasAllPlayersActed() then @endTurn()

  switch: (player, toPosition) =>
    # Record the switch
    @playerActions[player.id] =
      type: 'switch'
      to: toPosition

    # End the turn if each player has moved.
    if @hasAllPlayersActed() then @endTurn()

  # Returns true if all players have moved, false otherwise.
  hasAllPlayersActed: =>
    _.all(@players, (object) => object.player.id of @playerActions)

  endTurn: =>
    # Act on player actions.
    # TODO: Sort by priority and active pokemon speed.
    messages = []
    for clientId of @playerActions
      player = @getPlayer(clientId)
      action = @getAction(clientId)
      # TODO: abstract better?
      switch action.type
        when 'switch'
          team = @getTeam(clientId)
          messages.push "#{player.name} withdrew #{team[0].name}!"
          [team[0], team[action.to]] = [team[action.to], team[0]]
          messages.push "#{player.name} sent out #{team[0].name}!"
        when 'move'
          player = @getPlayer(clientId)
          pokemon = @getTeam(clientId)[0]
          # TODO: Make this nicer.
          for opponent in @getOpponents(clientId)
            # todo: the move should be cloned and attached to the pokemon
            defender = @getTeam(opponent.player.id)[0]
            move = moves[action.name]

            # Any before move events
            move.execute(this, pokemon, defender)
            # Any after move events

            messages.push "#{player.username}'s #{pokemon.name} used #{move.name}!"
          # TODO: Apply multi-target and weather modifiers
          # TODO: Apply random factor
          # TODO: Apply STAB
          # TODO: Apply type-effectiveness
          # TODO: Apply burn

      # Clean up playerActions hash.
      delete @playerActions[clientId]

    # Send a message to each player about the end of turn.
    messages.push 'end turn!'
    for object in @players
      object.player.emit? 'updatechat', 'SERVER', messages.join('<br>')

  damage: (attacker, defender, damage) =>
    defender.currentHP -= damage

  # Returns a random integer N such that min <= N <= max.
  randInt: (min, max) =>
    Math.floor(@rng.next() * (max + 1 - min) + min)
