Bookshelf = require('bookshelf')
config = require('../knex_config').database

Bookshelf.PG = PG = Bookshelf.initialize(config)

Team = PG.Model.extend
  tableName: 'teams'
  hasTimestamps: ['created_at', 'updated_at']

  toJSON: -> {
      id: @id
      name: @get('name')
      generation: @get('generation')
      pokemon: JSON.parse(@get('contents'))
    }

Teams = PG.Collection.extend
  model: Team

module.exports = {Team, Teams}
