JST['battle'] = thermos.template (locals) ->
  @div '.wrapper', ->
    @div '.battle_pane.clearfix', ->
      for i in [0...2]
        hpClass = (if i == locals.yourIndex then ".bottom" else ".top")
        spriteClass = (if i == locals.yourIndex then ".back" else ".front")
        team = (if i == locals.yourIndex then locals.team else locals.opponent)
        for j in [0...locals.numActive]
          pokemon = team[j]
          percent = Math.floor(pokemon.hp * 100 / pokemon.maxHP)
          color = (if percent <= 25 then "#f00" else if percent <= 50 then "#ff0" else "#0f0")
          style = "width: #{percent}%; background-color: #{color}"
          @div ".preload#{spriteClass}", data: { name: pokemon.name }
          @div ".hp_bar#{hpClass}.hp#{i}-#{j}", ->
            @div '.hp-red', style: style
            @div '.hp', style: style

    @div '.battle_actions.row-fluid'
