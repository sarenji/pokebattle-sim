
exports.up = (knex, Promise) ->
  knex.schema.createTable 'teams', (t) ->
    t.increments()
    t.integer('trainer_id').index().notNull()
    t.string('name').notNull()
    t.string('generation').notNull()
    t.json('contents')
    t.timestamps()

exports.down = (knex, Promise) ->
  knex.schema.dropTableIfExists 'teams'
