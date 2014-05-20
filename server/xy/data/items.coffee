GEM_BOOST_AMOUNT = 0x14CD

coffee = require 'coffee-script'
path = require('path').resolve(__dirname, '../../bw/data/items.coffee')
eval(coffee.compile(require('fs').readFileSync(path, 'utf8'), bare: true))

makeTypeResistBerry 'Roseli Berry', 'Fairy'
makeBoostOnTypeItem 'Luminous Moss', 'Water', specialDefense: 1
makeBoostOnTypeItem 'Snowball', 'Ice', attack: 1
makePlateItem 'Pixie Plate', 'Fairy'

makeItem "Assault Vest", ->
  this::beginTurn = ->
    for move in @pokemon.moves
      if move.isNonDamaging()
        @pokemon.blockMove(move)

  this::editSpecialDefense = (defense) ->
    Math.floor(defense * 1.5)

makeItem "Kee Berry", ->
  this.eat = (battle, owner) ->
    owner.boost(defense: 1)

  this::afterBeingHit = (move, user) ->
    if move.isPhysical()
      @battle.message("#{@pokemon.name}'s #{@displayName} berry activated!")
      @constructor.eat(@battle, @pokemon)
      @pokemon.useItem()

makeItem "Maranga Berry", ->
  this.eat = (battle, owner) ->
    owner.boost(specialDefense: 1)

  this::afterBeingHit = (move, user) ->
    if move.isSpecial()
      @battle.message("#{@pokemon.name}'s #{@displayName} berry activated!")
      @constructor.eat(@battle, @pokemon)
      @pokemon.useItem()

makeItem "Safety Goggles", ->
  this::isWeatherDamageImmune = -> true

  this::shouldBlockExecution = (move, user) ->
    return true  if move.hasFlag("powder")

makeItem "Weakness Policy", ->
  this::afterBeingHit = (move, user, target, damage, isDirect) ->
    if isDirect && !move.isNonDamaging() &&
        move.typeEffectiveness(@battle, user, @pokemon) > 1
      @pokemon.boost(attack: 2, specialAttack: 2)
      @pokemon.useItem()
