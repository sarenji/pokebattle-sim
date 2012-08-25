JST['battle_actions'] = thermos.template (locals) ->
  @h2 "Moves"
  # TODO: if locals.team[0].isAlive()
  console.log locals.team
  @div ->
    for move in locals.team[0].moves
      @button ".move", move

  @h2 "Pokemon"
  @div ->
    for pokemon in locals.team
      @button ".switch", pokemon.name
