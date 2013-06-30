JST['battle_actions'] = thermos.template (locals) ->
  actions = locals.validActions
  @div '.wrapper', ->
    @div '.battle_pane.clearfix', ->
      pokemon = locals.team[0]
      @img '.back', src: "/images/bw/back/#{PokemonData[pokemon.name].id}.png"
      opponent = locals.opponent[0]
      @img '.front', src: "/images/bw/#{PokemonData[opponent.name].id}.png"

    if actions.moves?.length > 0
      @h2 "Moves"
      # TODO: if locals.team[0].isAlive()
      @div '.clearfix', ->
        moves = locals.team[0].moves
        templ = (move) =>
          isEnabled = move.toLowerCase().replace(/\s+/g, '-') in actions.moves
          @div ".move.button#{if !isEnabled then '.disabled' else ''}", ->
            @div '.main_text', -> move
            @div '.meta_info', -> "15/15"
        for i in [0...moves.length] by 2
          @div '.left', ->
            templ(moves[i])
            templ(moves[i + 1])  if moves[i + 1]?

    if actions.switches?.length > 0
      @h2 "Pokemon"
      @div '.clearfix', ->
        for pokemon, i in locals.team
          isEnabled = (i in actions.switches)
          @div ".switch.button.small#{if !isEnabled then '.disabled' else ''}", ->
            @div '.main_text', ->
              @img '.pokemon_icon.left', src: "/images/icons/#{PokemonData[pokemon.name].id}.png"
              @text pokemon.name
