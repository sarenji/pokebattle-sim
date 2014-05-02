
exports.up = (knex, Promise) ->
  knex.raw('ALTER TABLE teams ALTER COLUMN name DROP NOT NULL')
    .then ->
      knex.raw('ALTER TABLE teams ALTER COLUMN generation DROP NOT NULL')


exports.down = (knex, Promise) ->
  knex.raw('ALTER TABLE teams ALTER COLUMN name SET NOT NULL')
    .then ->
      knex.raw('ALTER TABLE teams ALTER COLUMN generation SET NOT NULL')
