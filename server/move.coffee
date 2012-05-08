class @Move
  constructor: (@name, attributes = {}) ->
    @attributes = attributes
    @priority = attributes.priority || 0

  # Executes the move on the target. Target may be null
  # if the move attacks all opponents
  execute: (battle, user, target) ->
    baseDamage = battle.baseDamage(user, target, @attributes)
    battle.damage(user, target, baseDamage)
