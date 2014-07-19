{_} = require('underscore')
{Formats} = require('../shared/conditions')
config = require('../knexfile')[process.env.NODE_ENV || 'development']

knex = require('knex')(config)
bookshelf = require('bookshelf')(knex)

# Postgres 9.2+ support the JSON datatype. Other versions/DBs do not.
# So if the JSON data type is supported, then loading will load as JSON.
jsonify = (contents) ->
  if _.isObject(contents)
    contents
  else if !contents || !contents.length
    {}
  else
    JSON.parse(contents)

Team = bookshelf.Model.extend
  tableName: 'teams'
  hasTimestamps: ['created_at', 'updated_at']

  toJSON: -> {
    id: @id
    name: @get('name')
    generation: @get('generation')
    pokemon: jsonify(@get('contents'))
  }

Teams = bookshelf.Collection.extend
  model: Team

Battle = bookshelf.Model.extend
  tableName: 'battles'
  hasTimestamps: ['created_at', 'updated_at']

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
    id: @get('battle_id')
    name: @getName()
    format: @get('format')
    numActive: @get('num_active')
    players: @getPlayerNames()
    contents: jsonify(@get('contents'))
    created_at: @get('created_at')
  }

SavedBattle = bookshelf.Model.extend
  tableName: 'saved_battles'
  hasTimestamps: ['created_at', 'updated_at']

SavedBattles = bookshelf.Collection.extend
  model: SavedBattle

module.exports = {Team, Teams, Battle, SavedBattle, SavedBattles, knex}
