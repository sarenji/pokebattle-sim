
exports.up = (knex, Promise) ->
  knex.schema.createTable 'battles', (t) ->
    t.increments()
    t.string('battle_id').index().unique().notNull()
    t.string('name')
    t.string('players').notNull()
    t.string('generation').notNull()
    t.integer('num_active').notNull()
    t.json('versions')
    t.json('contents').notNull()
    t.timestamps()

exports.down = (knex, Promise) ->
  knex.schema.dropTableIfExists 'battles'
