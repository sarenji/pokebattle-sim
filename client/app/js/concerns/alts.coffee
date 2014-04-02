alts = []

PokeBattle.events.on 'altList', (altList) ->
  alts = altList

PokeBattle.events.on 'altCreated', (altName) ->
  alts.push altName

PokeBattle.alts =
  listAlts: ->
    return alts
  createAlt: (altName) ->
    PokeBattle.socket.send('createAlt', altName)