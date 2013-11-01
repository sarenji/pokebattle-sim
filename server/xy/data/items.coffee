coffee = require 'coffee-script'
path = require('path').resolve(__dirname, '../../bw/data/items.coffee')
eval(coffee.compile(require('fs').readFileSync(path, 'utf8'), bare: true))

makeTypeResistBerry 'Roseli Berry', 'Fairy'
makeBoostOnTypeItem 'Luminous Moss', 'Water', specialDefense: 1
makeBoostOnTypeItem 'Snowball', 'Ice', attack: 1

makeItem "Weakness Policy", ->
  this::afterBeingHit = (move, user) ->
    if !move.isNonDamaging() &&
        move.typeEffectiveness(@battle, user, @pokemon) > 1
      @pokemon.boost(attack: 2, specialAttack: 2)
      @pokemon.useItem()
