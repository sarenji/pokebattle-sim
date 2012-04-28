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

  makeMove: (player, moveName) =>
    # TODO: Fail if move not in moves
    return  if moveName not of Moves

    # Store the move name that this player wants to make.
    @playerMoves[player.clientId] = moveName

    # End the turn if each player has moved.
    if _.all(@players, (player) => player.clientId of @playerMoves)
      @endTurn()

  endTurn: =>
    # Clean up hash
    for move of @playerMoves
      delete @playerMoves[move]

    # Send a message to each player about the end of turn.
    for player in @players
      player.emit 'updatechat', 'SERVER', 'end turn!'
