
exports.up = (knex, Promise) ->
  knex.schema.createTable 'saved_battles', (t) ->
    t.increments()
    t.string('battle_id').notNull()
    t.integer('user_id').index().notNull()
    t.unique(['battle_id', 'user_id'])
    t.timestamps()

exports.down = (knex, Promise) ->
  knex.schema.dropTableIfExists 'saved_battles'
