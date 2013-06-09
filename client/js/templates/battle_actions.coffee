JST['battle_actions'] = thermos.template (locals) ->
  @div '.wrapper', ->
    @h2 "Moves"
    # TODO: if locals.team[0].isAlive()
    console.log locals.team
    @div '.clearfix', ->
      moves = locals.team[0].moves
      templ = (move) =>
        @div ".move.button#{if locals.disabled then '.disabled' else ''}", ->
          @div '.main_text', -> move
          @div '.meta_info', -> "15/15"
      for i in [0...moves.length] by 2
        @div '.left', ->
          templ(moves[i])
          templ(moves[i + 1])  if moves[i + 1]?

    @h2 "Pokemon"
    @div '.clearfix', ->
      for pokemon in locals.team
        @div ".switch.button#{if locals.disabled then '.disabled' else ''}", ->
          @div '.main_text', -> pokemon.name
          @div '.meta_info', ->
            @div '.pokemon_icon.right'
