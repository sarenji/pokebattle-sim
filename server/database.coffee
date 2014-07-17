Bookshelf = require('bookshelf')
{_} = require('underscore')
config = require('../knex_config').database
{Formats} = require('../shared/conditions')

Bookshelf.PG = PG = Bookshelf.initialize(config)

# Postgres 9.2+ support the JSON datatype. Other versions/DBs do not.
# So if the JSON data type is supported, then loading will load as JSON.
jsonify = (contents) ->
  if _.isObject(contents)
    contents
  else if !contents || !contents.length
    {}
  else
    JSON.parse(contents)

Team = PG.Model.extend
  tableName: 'teams'
  hasTimestamps: ['created_at', 'updated_at']

  toJSON: -> {
    id: @id
    name: @get('name')
    generation: @get('generation')
    pokemon: jsonify(@get('contents'))
  }

Teams = PG.Collection.extend
  model: Team

Battle = PG.Model.extend
  tableName: 'battles'
  hasTimestamps: ['created_at', 'updated_at']

  savers: ->
    @hasMany(SavedBattle)

  # TODO: Find (and jsonify) asset versions

  getName: ->
    @get('name') || @getPlayerNames().join(' vs. ') || 'Untitled'

  getFormat: ->
    Formats[@get('format')].humanName

  getPlayerNames: ->
    # players is denormalized. It's an array with a comma delimiter.
    @get('players')?.split(',') || []

  version: (js) ->
    jsonify(@get('versions'))[js]

  toJSON: -> {
    id: @id
    name: @getName()
    format: @get('format')
    battleId: @get('battle_id')
    numActive: @get('num_active')
    players: @getPlayerNames()
    contents: jsonify(@get('contents'))
  }

SavedBattle = PG.Model.extend
  tableName: 'saved_battles'
  hasTimestamps: ['created_at', 'updated_at']

  battle: ->
    @belongsTo(Battle)

module.exports = {Team, Teams, Battle, SavedBattle}
