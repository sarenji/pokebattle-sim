JST['battle_actions'] = thermos.template (locals) ->
  @h2 "Moves"
  # TODO: if locals.team[0].isAlive()
  console.log locals.team
  @div '.clearfix', ->
    for move in locals.team[0].moves
      @div ".move.button", ->
        @div '.main_text', -> move
        @div '.meta_info', -> "15/15"

  @h2 "Pokemon"
  @div '.clearfix', ->
    for pokemon in locals.team
      @div ".switch.button", ->
        @div '.main_text', -> pokemon.name
        @div '.meta_info', ->
          @div '.pokemon_icon.right'
