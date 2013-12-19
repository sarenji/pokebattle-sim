coffee = require 'coffee-script'
path = require('path').resolve(__dirname, '../../bw/data/moves.coffee')
eval(coffee.compile(require('fs').readFileSync(path, 'utf8'), bare: true))

makeBoostMove 'Baby-Doll Eyes', 'target', attack: -1
makeBoostMove 'Confide', 'target', specialAttack: -1

extendMove "Defog", ->
  @entryHazards.push(Attachment.StickyWeb)
  @selectPlayers = (battle) ->
    battle.players

makeBoostMove 'Eerie Impulse', 'target', specialAttack: -2

extendMove 'Facade', ->
  @burnCalculation = -> 1

extendMove 'Knock Off', ->
  @basePower = (battle, user, target) ->
    multiplier = (if target.hasTakeableItem() then 1.5 else 1.0)
    Math.floor(multiplier * @power)

extendMove 'Hidden Power', ->
  @basePower = -> @power

makeProtectCounterMove "King's Shield", (battle, user, targets) ->
  user.attach(Attachment.KingsShield)
  battle.message "#{user.name} protected itself!"

extendWithSecondaryBoost 'Moonblast', 'target', .3, specialAttack: -1
extendWithSecondaryBoost 'Mystical Fire', 'target', 1, specialAttack: -1
makeBoostMove 'Noble Roar', 'target', attack: -1, specialAttack: -1
extendWithSecondaryStatus 'Nuzzle', 1, Status.Paralyze
makeBoostMove 'Play Nice', 'target', attack: -1
extendWithSecondaryBoost 'Play Rough', 'target', .1, attack: -1
extendWithSecondaryBoost 'Power-Up Punch', 'self', 1, attack: 1

extendMove "Rapid Spin", ->
  @entryHazards.push(Attachment.StickyWeb)

makeOpponentFieldMove 'Sticky Web', (battle, user, opponent) ->
  if opponent.attachToTeam(Attachment.StickyWeb)
    battle.message "A sticky web spreads out beneath #{opponent.id} team's feet!"
  else
    @fail(battle)
