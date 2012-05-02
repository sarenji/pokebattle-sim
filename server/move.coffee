class @Move
  constructor: (@name, attributes = {}) ->
    @attributes = attributes
    @priority = attributes.priority || 0

  # Executes the move on the target. Target may be null
  # if the move attacks all opponents
  execute: (battle, user, target) ->
    # todo: Emit this on the battle
    @beforeMove?()

    # todo: this should be part of some default battle action
    baseDamage = battle.baseDamage(user, target, @attributes)
    battle.damage(user, target, baseDamage)

    # todo: Emit this on the battle
    @afterMove?()

