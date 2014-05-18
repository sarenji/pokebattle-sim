# Prevents a clean escape while you're in a battle.
$(window).on 'beforeunload', ->
  if PokeBattle.battles.isPlaying()
    "You are currently in a battle."
  else
    # Do not prompt
    return
