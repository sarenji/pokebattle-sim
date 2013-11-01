coffee = require 'coffee-script'
path = require('path').resolve(__dirname, '../bw/attachment.coffee')
eval(coffee.compile(require('fs').readFileSync(path, 'utf8'), bare: true))

delete @Status.Sleep::switchOut

class @Attachment.KingsShield extends @VolatileAttachment
  name: "KingsShieldAttachment"

  shouldBlockExecution: (move, user) ->
    if move.hasFlag("protect") && !move.isNonDamaging()
      @battle.message "#{@pokemon.name} protected itself!"
      if move.hasFlag("contact") then user.boost(attack: -2)
      return true

  endTurn: ->
    @pokemon.unattach(@constructor)
