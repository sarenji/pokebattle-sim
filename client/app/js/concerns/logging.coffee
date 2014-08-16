PokeBattle.primus.on 'data', (args...) ->
  try
    console.log(args...)  if window.localStorage.debug == 'true'
  catch
