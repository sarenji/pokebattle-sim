{_} = require 'underscore'
{Pokemon} = require './pokemon'
{Attachments} = require './attachment'
{Protocol} = require '../../shared/protocol'
Query = require('./queries')

class @Team
  constructor: (@battle, @playerId, pokemon, @numActive) ->
    @pokemon = pokemon.map (attributes) =>
      # TODO: Is there a nicer way of doing these injections?
      attributes.battle = @battle
      attributes.team = this
      attributes.playerId = @playerId
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

  contains: (pokemon) ->
    @indexOf(pokemon) != -1

  first: ->
    @at(0)

  has: (attachment) ->
    @attachments.contains(attachment)

  get: (attachmentName) ->
    @attachments.get(attachmentName)

  attach: (attachment, options={}) ->
    options = _.clone(options)
    attachment = @attachments.push(attachment, options, battle: @battle, team: this)
    playerIndex = @battle.getPlayerIndex(@playerId)
    if attachment then @battle?.tell(Protocol.TEAM_ATTACH, playerIndex, attachment.name)
    attachment

  unattach: (klass) ->
    attachment = @attachments.unattach(klass)
    playerIndex = @battle.getPlayerIndex(@playerId)
    if attachment then @battle?.tell(Protocol.TEAM_UNATTACH, playerIndex, attachment.name)
    attachment

  switch: (pokemon, toPosition) ->
    newPokemon = @at(toPosition)
    index = @indexOf(pokemon)
    playerIndex = @battle.getPlayerIndex(@playerId)
    @battle.message "#{@playerId} withdrew #{pokemon.name}!"
    @battle.tell(Protocol.SWITCH_OUT, playerIndex, index)
    p.informSwitch(pokemon)  for p in @battle.getOpponents(pokemon)
    @switchOut(pokemon)
    @replace(pokemon, toPosition)
    @switchIn(newPokemon)

  replace: (pokemon, toPosition) ->
    [ a, b ] = [ @indexOf(pokemon), toPosition ]
    [@pokemon[a], @pokemon[b]] = [@pokemon[b], @pokemon[a]]
    newPokemon = @at(a)
    @battle.message "#{@playerId} sent out #{newPokemon.name}!"
    newPokemon.tell(Protocol.SWITCH_IN, b)
    newPokemon

  shouldBlockFieldExecution: (move, user) ->
    Query.untilTrue('shouldBlockFieldExecution', @attachments.all(), move, user)

  switchOut: (pokemon) ->
    Query('switchOut', @attachments.all(), pokemon)
    pokemon.switchOut()

  switchIn: (pokemon) ->
    pokemon.switchIn()
    Query('switchIn', @attachments.all(), pokemon)

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
    "owner": @playerId
  }
