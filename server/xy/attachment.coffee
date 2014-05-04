coffee = require 'coffee-script'
path = require('path').resolve(__dirname, '../bw/attachment.coffee')
eval(coffee.compile(require('fs').readFileSync(path, 'utf8'), bare: true))

delete @Status.Sleep::switchOut

# In XY, electric pokemon are immune to paralysis
@Status.Paralyze.worksOn = (battle, pokemon) ->
  !pokemon.hasType("Electric")

# In XY, Protect-like moves have a chance of success corresponding to the
# power of 3, instead of the power of 2 in previous generations.
@Attachment.ProtectCounter::successMultiplier = 3

# In XY, partial-trapping moves deal more damage at the end of each turn
@Attachment.Trap::getDamagePerTurn = ->
  if @user.hasItem("Binding Band")
    6
  else
    8

class @Attachment.KingsShield extends @VolatileAttachment
  name: "KingsShieldAttachment"

  shouldBlockExecution: (move, user) ->
    if move.hasFlag("protect") && !move.isNonDamaging()
      @battle.cannedText('PROTECT_CONTINUE', @pokemon)
      if move.hasFlag("contact") then user.boost(attack: -2, @pokemon)
      return true

  endTurn: ->
    @pokemon.unattach(@constructor)

class @Attachment.SpikyShield extends @VolatileAttachment
  name: "SpikyShieldAttachment"

  shouldBlockExecution: (move, user) ->
    if move.hasFlag("protect")
      @battle.cannedText('PROTECT_CONTINUE', @pokemon)
      if move.hasFlag("contact") then user.damage(user.stat('hp') >> 3)
      return true

  endTurn: ->
    @pokemon.unattach(@constructor)

class @Attachment.StickyWeb extends @TeamAttachment
  name: "StickyWebAttachment"

  initialize: ->
    id = @team.playerId
    @battle.cannedText('STICKY_WEB_START', @battle.getPlayerIndex(id))

  switchIn: (pokemon) ->
    if !pokemon.isImmune("Ground")
      @battle.cannedText('STICKY_WEB_CONTINUE', pokemon)
      # The source is not actually an opposing Pokemon, but in order for Defiant
      # to work properly, the source should not be the pokemon itself.
      pokemon.boost(speed: -1, @battle.getAllOpponents(pokemon)[0])

  unattach: ->
    id = @team.playerId
    @battle.cannedText('STICKY_WEB_END', @battle.getPlayerIndex(id))
