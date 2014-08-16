PokeBattle.primus.on 'altList', (list) ->
  PokeBattle.alts.list = list

PokeBattle.primus.on 'altCreated', (altName) ->
  PokeBattle.alts.list.push(altName)

PokeBattle.alts =
  list: []
  createAlt: (altName) ->
    PokeBattle.primus.send('createAlt', altName)
