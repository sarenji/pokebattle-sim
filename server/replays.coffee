{_} = require('underscore')
database = require('./database')
assets = require('../assets')

@MAX_SAVED_BATTLES = 15

class @TooManyBattlesSaved extends Error
  constructor: ->
    super("You can only save up to #{exports.MAX_SAVED_BATTLES} replays.")

@routes =
  show: (req, res) ->
    database.Battle
    .where(battle_id: req.params.id)
    .fetch()
    .then (replay) ->
      res.render('replays/show', bodyClass: 'no-sidebar', replay: replay)
    .catch (err) ->
      console.error(err.stack)
      res.render('replays/show', bodyClass: 'no-sidebar', replay: null)

  index: (req, res) ->
    database.SavedBattles
    .query()
    .where(user_id: req.user.id)
    .select('battle_id')
    .then (battleIds) ->
      battleIds = _.pluck(battleIds, 'battle_id')
      database.Battle
      .query('where', 'battle_id', 'in', battleIds)
      .fetchAll()
    .then (replays) ->
      res.render('replays/index', bodyClass: 'no-sidebar', replays: replays)
    .catch (err) ->
      console.error(err.stack)
      res.render('replays/index', bodyClass: 'no-sidebar', replays: [])

  destroy: (req, res) ->
    battleId = req.param('id')
    database.SavedBattle.query()
    .where(user_id: req.user.id, battle_id: battleId)
    .delete()
    .then ->
      database.knex(database.SavedBattle::tableName)
      .where(battle_id: battleId).count('*')
    .then (results) ->
      # If no more saves of this replay exist, delete the replay itself.
      if Number(results[0].count) == 0
        database.Battle.query().where(battle_id: battleId).delete()
    .then ->
      res.json(ok: true)
    .catch (err) ->
      console.log(err.stack)
      res.json(ok: false)

@create = (user, battle) ->
  database.knex(database.SavedBattle::tableName)
  .where(user_id: user.id).count('*')
  .then (numSaved) ->
    if numSaved >= exports.MAX_SAVED_BATTLES
      throw new exports.TooManyBattlesSaved()
  .then ->
    new database.Battle({
      battle_id: battle.id
      format: battle.format
      num_active: battle.numActive
      players: battle.playerNames.join(',')
      contents: JSON.stringify(battle.log)
      versions: assets.asHash()
    }).save().catch (err) ->
      throw err  unless /violates unique constraint/.test(err.message)
  .then ->
    new database.SavedBattle(user_id: user.id, battle_id: battle.id)
    .save().catch (err) ->
      throw err  unless /violates unique constraint/.test(err.message)
  .then ->
    battle.id
  .catch (err) ->
    console.log(err.stack)
    throw err
