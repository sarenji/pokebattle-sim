coffee = require 'coffee-script'
path = require('path').resolve(__dirname, '../bw/pokemon.coffee')
eval(coffee.compile(require('fs').readFileSync(path, 'utf8'), bare: true))

@Pokemon::canMegaEvolve = ->
  return false  if @item.type != 'megastone'
  [ species, forme ] = @item.mega
  return false  if @name != species || @forme != 'default'
  return false  if @team?.filter((p) -> /^mega/.test(p.forme)).length > 0
  return true
