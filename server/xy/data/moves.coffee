coffee = require 'coffee-script'
path = require('path').resolve(__dirname, '../../bw/data/moves.coffee')
eval(coffee.compile(require('fs').readFileSync(path, 'utf8'), bare: true))

makeBoostMove 'Baby-Doll Eyes', 'target', attack: -1
makeBoostMove 'Confide', 'target', specialAttack: -1

extendMove "Defog", ->
  @entryHazards.push(Attachment.StickyWeb)
  @selectPlayers = (battle) ->
    battle.playerIds

makeBoostMove 'Eerie Impulse', 'target', specialAttack: -2

extendMove 'Facade', ->
  @burnCalculation = -> 1

extendMove 'Freeze-Dry', ->
  @superEffectiveAgainst = "Water"

extendMove 'Knock Off', ->
  @basePower = (battle, user, target) ->
    multiplier = (if target.hasTakeableItem() then 1.5 else 1.0)
    Math.floor(multiplier * @power)

extendMove 'Hidden Power', ->
  @basePower = -> @power

makeProtectCounterMove "King's Shield", (battle, user, targets) ->
  user.attach(Attachment.KingsShield)
  battle.message "#{user.name} protected itself!"

makeBoostMove 'Noble Roar', 'target', attack: -1, specialAttack: -1
makeBoostMove 'Play Nice', 'target', attack: -1

extendMove "Rapid Spin", ->
  @entryHazards.push(Attachment.StickyWeb)

makeProtectCounterMove "Spiky Shield", (battle, user, targets) ->
  user.attach(Attachment.SpikyShield)
  battle.message "#{user.name} protected itself!"

makeOpponentFieldMove 'Sticky Web', (battle, user, opponentId) ->
  team = battle.getTeam(opponentId)
  if team.attach(Attachment.StickyWeb)
    battle.message "A sticky web spreads out beneath #{opponentId} team's feet!"
  else
    @fail(battle)
