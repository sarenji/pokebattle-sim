# Create the move objects of every single move in the game

@MoveData = require('./data_moves.json')
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
#   extendMove 'substitute', (attributes) ->
#     @initialize -> # blah
#     @afterMove -> # blah
#
extendMove = (name, callback) ->
  move = moves[name]
  # todo: error if it doesn't exist

  # todo: Use an adapter so that it works like in the example
  callback.call(move, move.attributes)

# Extends a move in the move list as a move with a secondary effect.
# The chance of the effect is determined by the value of the
# effectChance attribute.
#
# name - The name of the move to turn into a secondary effect attack.
# effect - The name of the status to inflict, or a callback that inflicts
#          that status.
#
# Example:
#
#   TODO: Make example
#
makeSecondaryEffectMove = (name, effect) ->
  extendMove name, (attributes) ->
    # TODO: Error if attributes has no effectChance defined
    # TODO: implement after creating an afterSuccessfulHit hook


extendMove 'splash', ->
  # TODO: Cannot select if Gravity is in effect.
  @execute = (battle, user, target) ->
    battle.message "But nothing happened!"


makeSecondaryEffectMove 'flamethrower'