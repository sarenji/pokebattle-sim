coffee = require 'coffee-script'
path = require('path').resolve(__dirname, '../bw/pokemon.coffee')
eval(coffee.compile(require('fs').readFileSync(path, 'utf8'), bare: true))

@Pokemon::canMegaEvolve = ->
  return false  if !@hasItem()
  return false  if @item.type != 'megastone'
  [ species, forme ] = @item.mega
  return false  if @species != species || @forme != 'default'
  return false  if @team?.filter((p) -> /^mega/.test(p.forme)).length > 0
  return true

oldBlockSwitch = @Pokemon::blockSwitch
@Pokemon::blockSwitch = ->
  oldBlockSwitch.apply(this, arguments)  if !@hasType("Ghost")

oldHasTakeableItem = @Pokemon::hasTakeableItem
@Pokemon::hasTakeableItem = ->
  return false  if oldHasTakeableItem.apply(this, arguments) == false
  if @item.type == 'megastone'
    [ species, forme ] = @item.mega
    return false  if @species == species
  return true

# Powder moves no longer affect Grass-type Pokemon.
oldShouldBlockExecution = @Pokemon::shouldBlockExecution
@Pokemon::shouldBlockExecution = (move, user) ->
  if move.hasFlag("powder") && @hasType("Grass")
    move.fail(@battle)
    return true
  oldShouldBlockExecution.apply(this, arguments)

# In XY, Stance Change is another specially hardcoded ability that cannot change
oldHasChangeableAbility = @Pokemon::hasChangeableAbility
@Pokemon::hasChangeableAbility = ->
  !@hasAbility("Stance Change") && oldHasChangeableAbility.call(this)
