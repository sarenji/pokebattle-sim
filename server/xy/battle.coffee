coffee = require 'coffee-script'
path = require('path').resolve(__dirname, '../bw/battle.coffee')
eval(coffee.compile(require('fs').readFileSync(path, 'utf8'), bare: true))

{Ability} = require('./data/abilities')

@Battle::generation = 'xy'

@Battle::actionMap['mega'] =
  priority: -> 5
  action: (action) ->
    @performMegaEvolution(action.pokemon)

@Battle::performMegaEvolution = (pokemon) ->
  [ species, forme ] = pokemon.item.mega
  pokemon.changeForme(forme)

  ability = @FormeData[species][forme]["abilities"][0]
  ability = Ability[ability.replace(/\s+/g, '')]
  pokemon.copyAbility(ability)
  # We set the original ability to this ability so that the ability
  # is not reset upon switch out.
  pokemon.originalAbility = ability
  pokemon.originalForme = forme

  # Generate and display mega-evolution message
  pieces = forme.split('-').map((s) -> s[0].toUpperCase() + s.substr(1))
  pieces.splice(1, 0, species)
  megaFormeName = pieces.join(" ")
  @message "#{pokemon.name} Mega Evolved into #{megaFormeName}!"

# Retrofit `recordMove` to also record mega evolutions.
oldRecordMove = @Battle::recordMove
@Battle::recordMove = (playerId, move, forSlot = 0, megaEvolve = false) ->
  pokemon = @getTeam(playerId).at(forSlot)
  if megaEvolve && !@getAction(pokemon) && pokemon.canMegaEvolve()
    if @pokemonActions.filter((o) -> o.type == 'mega' && o.pokemon.team == pokemon.team).length == 0
      @addAction(type: 'mega', pokemon: pokemon)
  oldRecordMove.apply(this, arguments)
