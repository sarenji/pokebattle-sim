database = require('./database')
Promise = require('bluebird')

@MAX_SAVED_BATTLES = 15

class @TooManyBattlesSaved extends Error
  constructor: ->
    super("You can only save up to #{exports.MAX_SAVED_BATTLES} replays.")

@routes =
  show: (req, res) ->
    new database.Battle(battle_id: req.params.id)
    .fetch()
    .then (replay) ->
      res.render('replays/show', bodyClass: 'no-sidebar', replay: replay)

  index: (req, res) ->
    new database.SavedBattle(user_id: req.user.id)
    .fetch(withRelated: 'battle')
    .map (result) ->
      result.related('battle')
    .finally (replays = []) ->
      res.render('replays/index', bodyClass: 'no-sidebar', replays: replays)

@create = (user, battle) ->
  database.knex(database.SavedBattle::tableName)
  .where(user_id: user.id).count('*')
  .then (numSaved) ->
    if numSaved >= exports.MAX_SAVED_BATTLES
      throw new exports.TooManyBattlesSaved()
  .then ->
    new database.Battle({
      format: battle.format
      battle_id: battle.id
      num_active: battle.numActive
      players: battle.playerNames.join(',')
      contents: JSON.stringify(battle.log)
    }).save().catch (err) ->
      throw err  unless /violates unique constraint/.test(err.message)
  .then (battle) ->
    new database.SavedBattle(user_id: user.id, battle_id: battle.id)
    .save().catch (err) ->
      throw err  unless /violates unique constraint/.test(err.message)
  .then ->
    # the string id
    battle.id
  .catch (err) ->
    console.log(err.stack)
    throw err
