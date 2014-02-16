coffee = require 'coffee-script'
path = require('path').resolve(__dirname, '../../bw/data/moves.coffee')
eval(coffee.compile(require('fs').readFileSync(path, 'utf8'), bare: true))

extendMove "Defog", ->
  @entryHazards.push(Attachment.StickyWeb)
  @selectPlayers = (battle) ->
    battle.playerIds

extendWithDrain('Draining Kiss', .75)

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

makeTrappingMove "Infestation"
extendWithDrain('Oblivion Wing', .75)

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
