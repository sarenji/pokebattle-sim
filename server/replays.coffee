database = require('./database')

@routes =
  show: (req, res) ->
    new database.Battle(battle_id: req.params.id)
      .fetch()
      .then (replay) ->
        res.render('replays/show', bodyClass: 'no-sidebar', replay: replay)

  index: (req, res) ->
    new database.SavedBattle(user_id: req.user.id)
      .fetch(withRelated: ['battle'])
      .then (results) ->
        replays = results.map((result) -> result.related('battle'))
        res.render('replays/index', bodyClass: 'no-sidebar', replays: replays)

@create = (battle) ->
  new database.Battle({
    generation: battle.generation
    battle_id: battle.id
    num_active: battle.numActive
    players: battle.playerNames.join(',')
    contents: JSON.stringify(battle.log)
  }).save().catch (err) ->
    console.error(err.stack)
