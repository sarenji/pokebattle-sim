Bookshelf = require('bookshelf')
{_} = require('underscore')
config = require('../knex_config').database

Bookshelf.PG = PG = Bookshelf.initialize(config)

Team = PG.Model.extend
  tableName: 'teams'
  hasTimestamps: ['created_at', 'updated_at']

  toJSON: ->
    contents = @get('contents')
    {
      id: @id
      name: @get('name')
      generation: @get('generation')
      # Postgres 9.2+ support the JSON datatype. Other versions/DBs do not.
      # So if the JSON data type is supported, then loading will load as JSON.
      pokemon: (if _.isObject(contents) then contents else JSON.parse(contents))
    }

Teams = PG.Collection.extend
  model: Team

module.exports = {Team, Teams}
