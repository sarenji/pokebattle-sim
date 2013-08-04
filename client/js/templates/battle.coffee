JST['battle'] = thermos.template (locals) ->
  @div '.battle_pane.clearfix', ->
    for i in [0...2]
      infoClass = (if i == locals.yourIndex then ".bottom" else ".top")
      spriteClass = (if i == locals.yourIndex then ".back" else ".front")
      team = (if i == locals.yourIndex then locals.team else locals.opponent)
      for j in [0...locals.numActive]
        pokemon = team[j]
        percent = Math.floor(pokemon.hp * 100 / pokemon.maxHP)
        color = (if percent <= 25 then "#f00" else if percent <= 50 then "#ff0" else "#0f0")
        style = "width: #{percent}%"
        greenStyle = "#{style}; background-color: #{color}"
        @div ".pokemon#{i}-#{j}", ->
          @div ".sprite.preload#{spriteClass}", data: { name: pokemon.name }
          @div ".pokemon-info#{infoClass}", ->
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
