{_} = require 'underscore'
{Pokemon} = require './pokemon'

class @Team
  {species} = require '../data/bw'

  constructor: (pokemon, @numActive) ->
    @pokemon = pokemon.map (attributes) ->
      specimen = species[attributes.name]
      # TODO: Make nicer.
      attributes.weight = specimen.weight
      attributes.stats = _.clone(specimen.stats || {})
      pokemon_moves = attributes.moves || []
      attributes.moves = pokemon_moves.filter((m) -> m in specimen.moves)
      attributes.types = (type  for type in specimen.types || [])
      attributes.species = specimen.species
      new Pokemon(attributes)
    @attachments = []

  at: (index) =>
    @pokemon[index]

  all: =>
    @pokemon.slice(0)

  slice: (args...) =>
    @pokemon.slice(args...)

  indexOf: (pokemon) =>
    @pokemon.indexOf(pokemon)

  first: =>
    @at(0)

  hasAttachment: (name) =>
    name in @attachments.map((a) -> a.name)

  attach: (attachment) =>
    attachment.team = this
    @attachments.push(attachment)

  unattach: (attachment) =>
    index = @attachments.indexOf(attachment)
    @attachments.splice(index, 1)
    delete attachment.team

  switch: (a, b) =>
    [@pokemon[a], @pokemon[b]] = [@pokemon[b], @pokemon[a]]
    # TODO: Call switchOut on any inactive pokemon

  beginTurn: (battle) =>
    attachment.beginTurn(battle)  for attachment in @attachments

  endTurn: (battle) =>
    attachment.endTurn(battle)  for attachment in @attachments

  switchOut: (battle) =>
    attachment.switchOut(battle)  for attachment in @attachments

  getActivePokemon: =>
    @pokemon.slice(0, @numActive)

  getAlivePokemon: =>
    @pokemon.filter((pokemon) -> !pokemon.isFainted())

  getActiveFaintedPokemon: =>
    @getActivePokemon().filter((pokemon) -> pokemon.isFainted())

  getFaintedPokemon: =>
    @pokemon.filter((pokemon) -> pokemon.isFainted())

  getBenchedPokemon: =>
    @pokemon.slice(@numActive)

  getAliveBenchedPokemon: =>
    @getBenchedPokemon().filter((pokemon) -> !pokemon.isFainted())

  validate: =>
    # TODO
    true
