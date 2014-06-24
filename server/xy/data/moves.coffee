coffee = require 'coffee-script'
path = require('path').resolve(__dirname, '../../bw/data/moves.coffee')
eval(coffee.compile(require('fs').readFileSync(path, 'utf8'), bare: true))

extendMove "Defog", ->
  @entryHazards.push(Attachment.StickyWeb)
  @selectPokemon = (battle, user, target) ->
    [ target, user ]

extendMove 'Facade', ->
  @burnCalculation = -> 1

extendMove 'Fell Stinger', ->
  @afterSuccessfulHit = (battle, user, target) ->
    user.boost(attack: 2)  if target.isFainted()

extendMove 'Freeze-Dry', ->
  @superEffectiveAgainst = "Water"

makeChargeMove 'Geomancy', "$1 is absorbing power!"

extendMove 'Knock Off', ->
  @basePower = (battle, user, target) ->
    multiplier = (if target.hasTakeableItem() then 1.5 else 1.0)
    Math.floor(multiplier * @power)

extendMove 'Happy Hour', ->
  @afterSuccessfulHit = (battle, user, target) ->
    battle.message "Everyone is caught up in the happy atmosphere!"

extendMove 'Hidden Power', ->
  @basePower = -> @power

makeProtectCounterMove "King's Shield", (battle, user, targets) ->
  user.attach(Attachment.KingsShield)

makeTrappingMove "Infestation"

extendMove 'Nature Power', ->
  @execute = (battle, user, targets) ->
    # In Wi-Fi battles, Tri Attack is always chosen.
    battle.message "#{@name} turned into Tri Attack!"
    triAttack = battle.getMove('Tri Attack')
    battle.executeMove(triAttack, user, targets)

extendMove "Parting Shot", ->
  @afterSuccessfulHit = (battle, user, target) ->
    target.boost(attack: -1, specialAttack: -1, user)
    battle.forceSwitch(user)

makeChargeMove 'Phantom Force', [], "$1 vanished instantly!"

extendMove "Rapid Spin", ->
  @entryHazards.push(Attachment.StickyWeb)

makeProtectCounterMove "Spiky Shield", (battle, user, targets) ->
  user.attach(Attachment.SpikyShield)

makeOpponentFieldMove 'Sticky Web', (battle, user, opponentId) ->
  team = battle.getTeam(opponentId)
  if !team.attach(Attachment.StickyWeb)
    @fail(battle)

extendMove 'Topsy-Turvy', ->
  @afterSuccessfulHit = (battle, user, target) ->
    if target.hasBoosts()
      boosts = {}
      for stage, value of target.stages
        boosts[stage] = -value
      target.setBoosts(boosts)
      battle.message "#{target.name}'s stat changes were all reversed!"
    else
      @fail(battle)

extendMove 'Toxic', ->
  @getAccuracy = (battle, user, target) ->
    return 0  if user.hasType("Poison")
    return @accuracy

extendMove 'Venom Drench', ->
  @use = (battle, user, target) ->
    if !target.has(Status.Poison)
      @fail(battle)
      return false

    target.boost(attack: -1, specialAttack: -1, speed: -1)
