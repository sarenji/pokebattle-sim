# Create the move objects of every single move in the game

@MoveData = require('./moves.yml').pop()
{Move} = require('../../server/move.coffee')

# Generate the initial versions of every single move.
# Some of these will be overwritten later.
@moves = moves = {}
for name, attributes of @MoveData
  @moves[name] = new Move(name, attributes)


# Extends a move in the move list using a callback.
#
# name -      The name of the move to extend.
# callback -  The function that will extend the move. 'this'
#             is the move object itself.
#
# Example:
#
#   extendMove 'flamethrower', (attributes) ->
#     @initialize -> # blah
#     @afterMove -> # blah
#
extendMove = (name, callback) ->
  move = moves[name]
  # todo: error if it doesn't exist

  # todo: Use an adapter so that it works like in the example
  callback.call(move, move.attributes)

extendMove 'splash', ->
  # make splash do nothing
