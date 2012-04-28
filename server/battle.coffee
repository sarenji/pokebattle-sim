{_} = require 'underscore'
require 'js-yaml'

class @Battle
  # TODO: let Battle serialize these.
  @moves = Moves = require('../data/bw/moves.yml').pop()
  @pokemon = Pokemon = require('../data/bw/pokemon.yml').pop()

  constructor: (attributes = {}) ->
    {@players} = attributes

    # Stores the current turn of the battle
    @turn = 0

    # Stores the moves each player is about to make
    @playerMoves = {}

    # Maps clientId -> player
    @playerHash = {}
    for player in @players
      @playerHash[player.clientId] = player

  makeMove: (player, moveName) =>
    # TODO: Fail if move not in moves
    return  if moveName not of Moves

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

      # Clean up playerMoves hash.
      delete @playerMoves[clientId]

    # Send a message to each player about the end of turn.
    for player in @players
      player.emit? 'updatechat', 'SERVER', 'end turn!'
