{_} = require 'underscore'
{Pokemon} = require './pokemon'
{Attachments} = require './attachment'

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
    @attachments = new Attachments()

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

  hasAttachment: (attachment) =>
    @attachments.contains(attachment)

  getAttachment: (attachmentName) =>
    @attachments.get(attachmentName)

  attach: (attachment, options={}) =>
    options = _.clone(options)
    options.team = this
    @attachments.push(attachment, options)

  unattach: (attachment) =>
    ref = @attachments.unattach(attachment)
    return  if !ref?
    delete ref.team
    ref

  switch: (battle, player, a, b) =>
    battle.message "#{player.username} withdrew #{@at(a).name}!"
    p.informSwitch(battle, @at(a))  for p in battle.getOpponentPokemon(player.id)
    @switchOut(battle, @at(a))

    [@pokemon[a], @pokemon[b]] = [@pokemon[b], @pokemon[a]]

    battle.message "#{player.username} sent out #{@at(a).name}!"
    @switchIn(battle, @at(a))

  beginTurn: (battle) =>
    @attachments.query('beginTurn', battle)

  endTurn: (battle) =>
    @attachments.query('endTurn', battle)

  switchOut: (battle, pokemon) =>
    @attachments.query('switchOut', battle, pokemon)
    pokemon.switchOut(battle)

  switchIn: (battle, pokemon) =>
    pokemon.switchIn(battle)
    @attachments.query('switchIn', battle, pokemon)

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
