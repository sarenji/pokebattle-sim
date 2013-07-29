{_} = require 'underscore'
{Pokemon} = require './pokemon'
{Attachments} = require './attachment'

class @Team
  {Species} = require '../data/bw'

  constructor: (battle, player, pokemon, @numActive) ->
    # Inject battle dependency
    @battle = battle
    @player = player
    @pokemon = pokemon.map (attributes) =>
      specimen = Species[attributes.name]
      # TODO: Make nicer.
      attributes.battle = battle
      attributes.team = this
      attributes.player = player
      attributes.weight = specimen.weight
      attributes.stats = _.clone(specimen.stats || {})
      pokemon_moves = attributes.moves || []
      attributes.moves = pokemon_moves.filter((m) -> m in specimen.moves)
      attributes.types = (type  for type in specimen.types || [])
      attributes.species = specimen.species
      new Pokemon(attributes)
    @attachments = new Attachments()

  at: (index) ->
    @pokemon[index]

  all: ->
    @pokemon.slice(0)

  slice: (args...) ->
    @pokemon.slice(args...)

  indexOf: (pokemon) ->
    @pokemon.indexOf(pokemon)

  first: ->
    @at(0)

  has: (attachment) ->
    @attachments.contains(attachment)

  get: (attachmentName) ->
    @attachments.get(attachmentName)

  attach: (attachment, options={}) ->
    options = _.clone(options)
    @attachments.push(attachment, options, battle: @battle, team: this)

  unattach: (klass) ->
    attachment = @attachments.unattach(klass)
    delete attachment.team  if attachment?
    attachment

  switch: (player, a, b, options = {}) ->
    @battle.message "#{player.username} withdrew #{@at(a).name}!"
    p.informSwitch(@at(a))  for p in @battle.getOpponents(@at(a))
    @switchOut(@at(a))

    [@pokemon[a], @pokemon[b]] = [@pokemon[b], @pokemon[a]]
    p.tell(2, player.index, a, b)  for p in @battle.players

    @battle.message "#{player.username} sent out #{@at(a).name}!"
    @switchIn(@at(a))  unless options.silent == true
    @at(a).turnsActive = 0

  beginTurn: ->
    @attachments.query('beginTurn')

  endTurn: ->
    @attachments.query('endTurn')

  switchOut: (pokemon) ->
    @attachments.query('switchOut', pokemon)
    pokemon.switchOut()

  switchIn: (pokemon) ->
    pokemon.switchIn()
    @attachments.query('switchIn', pokemon)

  getAdjacent: (pokemon) ->
    index = @pokemon.indexOf(pokemon)
    adjacent = []
    return adjacent  if index < 0 || index >= @numActive
    adjacent.push(@at(index - 1))  if index > 1
    adjacent.push(@at(index + 1))  if index < @numActive - 1
    adjacent.filter((p) -> p.isAlive())

  getActivePokemon: ->
    @pokemon.slice(0, @numActive)

  getActiveAlivePokemon: ->
    @getActivePokemon().filter((pokemon) -> pokemon.isAlive())

  getAlivePokemon: ->
    @pokemon.filter((pokemon) -> !pokemon.isFainted())

  getActiveFaintedPokemon: ->
    @getActivePokemon().filter((pokemon) -> pokemon.isFainted())

  getFaintedPokemon: ->
    @pokemon.filter((pokemon) -> pokemon.isFainted())

  getBenchedPokemon: ->
    @pokemon.slice(@numActive)

  getAliveBenchedPokemon: ->
    @getBenchedPokemon().filter((pokemon) -> !pokemon.isFainted())

  validate: ->
    # TODO
    true

  toJSON: -> {
    "pokemon": @pokemon.map (p) -> p.toJSON()
  }
