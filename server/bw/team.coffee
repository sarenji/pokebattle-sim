{_} = require 'underscore'
{Pokemon} = require './pokemon'
{Attachments} = require './attachment'
{Protocol} = require '../../shared/protocol'

class @Team
  constructor: (battle, player, pokemon, @numActive) ->
    # Inject battle dependency
    @battle = battle
    @player = player
    @pokemon = pokemon.map (attributes) =>
      # TODO: Is there a nicer way of doing these injections?
      attributes.battle = battle
      attributes.team = this
      attributes.player = player
      new Pokemon(attributes)
    @attachments = new Attachments()

  arrange: (arrangement) ->
    @pokemon = (@pokemon[index]  for index in arrangement)

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
    attachment = @attachments.push(attachment, options, battle: @battle, team: this)
    if attachment then @battle?.tell(Protocol.TEAM_ATTACH, @player.index, attachment.name)
    attachment

  unattach: (klass) ->
    attachment = @attachments.unattach(klass)
    if attachment then @battle?.tell(Protocol.TEAM_UNATTACH, @player.index, attachment.name)
    attachment

  switch: (pokemon, toPosition) ->
    newPokemon = @at(toPosition)
    index = @indexOf(pokemon)
    @battle.message "#{@player.id} withdrew #{pokemon.name}!"
    @battle.tell(Protocol.SWITCH_OUT, @player.index, index)
    p.informSwitch(pokemon)  for p in @battle.getOpponents(pokemon)
    @switchOut(pokemon)
    @replace(pokemon, toPosition)
    @switchIn(newPokemon)

  replace: (pokemon, toPosition) ->
    [ a, b ] = [ @indexOf(pokemon), toPosition ]
    [@pokemon[a], @pokemon[b]] = [@pokemon[b], @pokemon[a]]
    newPokemon = @at(a)
    @battle.message "#{@player.id} sent out #{newPokemon.name}!"
    newPokemon.tell(Protocol.SWITCH_IN, b)
    newPokemon

  beginTurn: ->
    @attachments.query('beginTurn')

  shouldBlockFieldExecution: (move, user) ->
    @attachments.queryUntilTrue('shouldBlockFieldExecution', move, user)

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

  size: ->
    @pokemon.length

  filter: ->
    @pokemon.filter.apply(@pokemon, arguments)

  toJSON: (options = {}) -> {
    "pokemon": @pokemon.map (p) -> p.toJSON(options)
    "owner": @player.id
  }
