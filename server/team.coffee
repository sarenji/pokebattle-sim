{_} = require 'underscore'
{Pokemon} = require './pokemon'

class @Team
  {species} = require '../data/bw'

  constructor: (pokemon, @numActive) ->
    @pokemon = pokemon.map (attributes) ->
      specimen = species[attributes.name]
      # TODO: Make nicer.
      attributes.stats = _.clone(specimen.stats || {})
      pokemon_moves = attributes.moves || []
      attributes.moves = pokemon_moves.filter((m) -> m in specimen.moves)
      attributes.types = (type  for type in specimen.types || [])
      new Pokemon(attributes)

  at: (index) =>
    @pokemon[index]

  all: =>
    @pokemon.slice(0)

  indexOf: (pokemonName) =>
    names = @pokemon.map((p) -> p.name)
    names.indexOf(pokemonName)

  first: =>
    @at(0)

  switch: (a, b) =>
    [@pokemon[a], @pokemon[b]] = [@pokemon[b], @pokemon[a]]

  getActivePokemon: =>
    @pokemon.slice(0, @numActive)

  getAlivePokemon: =>
    @pokemon.filter((pokemon) -> !pokemon.isFainted())

  getFaintedPokemon: =>
    @pokemon.filter((pokemon) -> pokemon.isFainted())

  getBenchedPokemon: =>
    @pokemon.slice(@numActive)

  getAliveBenchedPokemon: =>
    @pokemon.slice(@numActive).filter((pokemon) -> !pokemon.isFainted())

  validate: =>
    # TODO
    true
