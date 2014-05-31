PokeBattle.primus.on 'data', (args...) ->
  console.log(args...)  if window.localStorage.debug == 'true'
