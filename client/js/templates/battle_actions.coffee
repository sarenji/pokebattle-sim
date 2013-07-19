JST['battle_actions'] = thermos.template (locals) ->
  actions = locals.validActions
  @div '.wrapper', ->
    @div '.battle_pane.clearfix', ->
      pokemon = locals.team[0]
      opponent = locals.opponent[0]
      @div '.preload.back', data: { name: pokemon.name }
      @div '.preload.front', data: { name: opponent.name }

    if actions.moves?.length > 0
      @h2 "Moves"
      # TODO: if locals.team[0].isAlive()
      @div '.clearfix', ->
        moves = locals.team[0].moves
        moveTypes = locals.team[0].moveTypes
        pps = locals.team[0].pp
        templ = (i) =>
          [move, moveType, pp] = [moves[i], moveTypes[i], pps[i]]
          isEnabled = move.toLowerCase().replace(/\s+/g, '-') in actions.moves
          disabledClass = (if !isEnabled then '.disabled' else '')
          moveType = moveType.toLowerCase()
          @div ".move.button.#{moveType}#{disabledClass}", ->
            @div '.main_text', -> move
            @div '.meta_info', -> "#{pp}/15"
        for i in [0...moves.length] by 2
          @div '.left', ->
            templ(i)
            templ(i + 1)  if i + 1 < moves.length

    if actions.switches?.length > 0
      @h2 "Pokemon"
      @div '.clearfix', ->
        for pokemon, i in locals.team
          isEnabled = (i in actions.switches)
          @div ".switch.button.small#{if !isEnabled then '.disabled' else ''}", ->
            @div '.main_text', ->
              @img '.pokemon_icon.left', src: "/images/icons/#{PokemonData[pokemon.name].id}.png"
              @text pokemon.name
