database = require('./database')

@routes =
  show: (req, res) ->
    new database.Battle(battle_id: req.params.id)
      .fetch()
      .then (replay) ->
        res.render('replay', bodyClass: 'no-sidebar', replay: replay)

@create = (battle) ->
  new database.Battle({
    generation: battle.generation
    battle_id: battle.id
    num_active: battle.numActive
    players: battle.playerNames.join(',')
    contents: JSON.stringify(battle.log)
  }).save().catch (err) ->
    console.error(err.stack)
