JST['battle_actions'] = thermos.template (locals) ->
  @div '.wrapper', ->
    @div '.battle_pane.clearfix', ->
      pokemon = locals.team[0]
      @div '.back', ->
        @img src: "/images/bw/back/#{PokemonData[pokemon.name].id}.png"
      opponent = locals.opponent[0]
      @div '.front', ->
        @img src: "/images/bw/#{PokemonData[opponent.name].id}.png"

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
        @div ".switch.button.small#{if locals.disabled then '.disabled' else ''}", ->
          @div '.main_text', ->
            @img '.pokemon_icon.left', src: "/images/icons/#{PokemonData[pokemon.name].id}.png"
            @text pokemon.name
