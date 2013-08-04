JST['battle'] = thermos.template (locals) ->
  @div '.battle_overlay', ->
    for team in [ locals.team, locals.opponent ]
      leftOrRight = (if team == locals.team then '.left' else '.right')
      @div leftOrRight, ->
        @text team.owner
        team = team.pokemon
        for j in [0...team.length] by 3
          @div '.row-fluid', ->
            for i in [j...(j + 3)]
              pokemon = team[i]
              id  = PokemonData[pokemon.name].id
              x   = (id % 16) * 32
              y   = (id >> 4) * 32
              pos = "-#{x}px -#{y}px"
              @div '.span4', ->
                @span '.pokemon_icon', style: "background-position: #{pos}"
  @div '.battle_pane.clearfix', ->
    for i in [0...2]
      pokemonClass = (if i == locals.yourIndex then ".bottom" else ".top")
      team = (if i == locals.yourIndex then locals.team else locals.opponent)
      team = team.pokemon
      for j in [0...locals.numActive]
        pokemon = team[j]
        percent = Math.floor(pokemon.hp * 100 / pokemon.maxHP)
        color = (if percent <= 25 then "#f00" else if percent <= 50 then "#ff0" else "#0f0")
        style = "width: #{percent}%"
        greenStyle = "#{style}; background-color: #{color}"
        @div ".pokemon.pokemon#{i}-#{j}#{pokemonClass}", ->
          @div ".sprite.preload", data: { name: pokemon.name }
          @div ".pokemon-info", ->
            @div '.pokemon-name', pokemon.name
            @div '.pokemon-meta', ->
              if pokemon.gender == 'F'
                @span '.gender.gender_female', "&#9792;"
              else if pokemon.gender == 'M'
                @span '.gender.gender_male', "&#9794;"
              @span '.pokemon-level', ' Lv.'
              @text pokemon.level
            @div '.hp-red', style: style
            @div '.hp', style: greenStyle
