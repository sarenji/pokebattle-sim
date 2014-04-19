class @BattleView extends Backbone.View
  battle_template: JST['battle']
  user_info_template: JST['battle_user_info']
  action_template: JST['battle_actions']
  team_preview_template: JST['battle_team_preview']

  events:
    'click .move': 'makeMove'
    'click .switch': 'switchPokemon'
    'click .mega-evolve': 'megaEvolve'
    'click .cancel': 'cancelAction'
    'click .save-log': 'saveLog'
    # Team arrangement
    'click .arrange_pokemon' : 'togglePokemonOrSwitch'
    'click .submit_arrangement': 'submitTeamPreview'

  initialize: =>
    @selected = null
    @chatView = null
    @lastMove = null
    @skip     = null
    @renderChat()
    @listenTo(@model, 'change:status', @handleStatus)
    @listenTo(@model, 'change:finished', @handleEnd)
    @battleStartTime = $.now()
    @timers = []
    @timerFrozenAt = []
    @timerIterations = 0
    @countdownTimers()

  renderBattle: =>
    locals =
      yourTeam     : @model.getTeam()
      opponentTeam : @model.getOpponentTeam()
      numActive    : @model.numActive
      yourIndex    : @model.index
      window       : window
    @$('.battle_pane').html @battle_template(locals)
    @renderPokemon()
    this

  renderPokemon: ($images, callback) =>
    $images ||= @$('.preload')
    battle = @model
    self = this
    $images.each ->
      $this = $(this)
      $pokemon = $this.closest('.pokemon')
      [player, slot] = [$pokemon.data('team'), $pokemon.data('slot')]
      front = $pokemon.hasClass('top')
      name  = $this.data('name')
      forme = $this.data('forme')
      shiny = $this.data('shiny')
      gen   = battle.get('generation').toUpperCase()
      {id}  = window.Generations[gen].SpeciesData[name]
      url   = PokemonSprite(id, forme, front: front, shiny: shiny)
      scale = if front then 1 else 1.3
      self.addPokemonImage $this, url, scale: scale, callback: ($image) ->
        image = $image[0]
        {width, height} = image
        [x, y] = self.getPokemonPosition(player, slot)
        x -= (width >> 1)
        y -= (height >> 1)
        $image.css(top: y, left: x).show()
        callback?($image)
    this

  renderChat: =>
    @chatView = new ChatView(
      el: @$('.chat')
      collection: @model.spectators
      chatEvent: 'sendBattleChat'
      chatArgs: [ @model.id ]
    ).render().renderUserList()
    this

  # TODO: Support 2v2
  renderActions: (validActions = []) =>
    locals =
      yourTeam     : @model.getTeam()
      validActions : validActions[0] || {}
      window       : window
    $actions = @$('.battle_actions')
    $actions.html @action_template(locals)

    pokemon = @model.getPokemon(@model.index, 0)
    if pokemon.getItem()?.type == 'megastone'
      $button = $actions.find('.mega-evolve')
      $button.removeClass("hidden")
      if !pokemon.canMegaEvolve()
        $button.addClass('disabled')

    $actions.find('.switch.button').each (i, el) =>
      $this = $(el)
      slot = $this.data('slot')
      pokemon = @model.getPokemon(@model.index, slot)
      @popover($this, pokemon)
    this

  renderWaiting: =>
    @$('.battle_actions').html """
    <div class="well well-battle-actions">Waiting for opponent... <a class="cancel">Cancel</a></div>
    """

  renderUserInfo: =>
    return  if !@model.teams
    locals =
      yourTeam     : @model.getTeam()
      opponentTeam : @model.getOpponentTeam()
      numActive    : @model.numActive
      yourIndex    : @model.index
      window       : window
    $userInfo = @$('.battle_user_info')
    $userInfo.find('.pokemon_icon').popover('destroy')
    $userInfo.html @user_info_template(locals)
    $userInfo.find('.pokemon_icon').each (i, el) =>
      $this = $(el)
      team = $this.data('team')
      slot = $this.data('slot')
      pokemon = @model.getPokemon(team, slot)
      @popover($this, pokemon)
    @renderTimers()
    this

  popover: ($this, pokemon) =>
    displayName = pokemon.get('name')
    displayName += " @ #{pokemon.get('item')}"  if pokemon.has('item')
    displayName += "<br>"
    for type in pokemon.getForme().types
      displayName += """<img src="#{TypeSprite(type)}" alt="#{type}"/>"""
    $this.popover
      title: displayName
      html: true
      content: JST['battle_hover_info']({window, pokemon})
      trigger: 'hover'
      animation: false
      container: "body"

  renderTeamPreview: =>
    locals =
      teams        : @model.teams
      numActive    : @model.numActive
      yourIndex    : @model.index
      isSpectating : @model.get('spectating')
      window       : window
    @$('.battle_container').append @team_preview_template(locals)

  togglePokemonOrSwitch: (e) =>
    $currentTarget = $(e.currentTarget)
    $activePokemon = @$('.arrange_pokemon.active')
    if $currentTarget.is('.active')
      $activePokemon.removeClass('active')
    else if $activePokemon.length > 0
      $activePokemon.removeClass('active')
      @swapElements($currentTarget.get(0), $activePokemon.get(0))
    else
      $currentTarget.addClass('active')

  swapElements: (element1, element2) ->
    [parent1, next1] = [element1.parentNode, element1.nextSibling]
    [parent2, next2] = [element2.parentNode, element2.nextSibling]

    parent1.insertBefore(element2, next1)
    parent2.insertBefore(element1, next2)

  submitTeamPreview: (e) =>
    $currentTarget = $(e.currentTarget)
    return  if $currentTarget.hasClass('disabled')
    $currentTarget.addClass('disabled')
    $teamPreview = @$('.battle_teams')
    indices = for element in @$('.arrange_team .pokemon_icon')
      $(element).data('index')
    @model.arrangeTeam(indices)
    $teamPreview.transition(opacity: 0, 250, => @removeTeamPreview())

  removeTeamPreview: =>
    $teamPreview = @$('.battle_teams')
    $teamPreview.remove()

  changeHP: (player, slot, oldPixels, done) =>
    $pokemon = @$pokemon(player, slot)
    $info = $pokemon.find(".pokemon-info")
    $hp = $info.find('.hp')
    $allHP = $info.find('.hp')
    $hpText = $info.find('.hp-text')
    pokemon = @model.getPokemon(player, slot)
    percent = pokemon.getPercentHP()
    percent = Math.max(percent, 0)
    if percent <= 20
      $hp.css(backgroundColor: "#f00")
    else if percent <= 50
      $hp.css(backgroundColor: "#ff0")
    else
      $hp.css(backgroundColor: "#0f0")
    $allHP.width("#{percent}%")
    $hpText.text("#{percent}%")
    deltaPercent = Math.floor(100 * (pokemon.get('pixels') - oldPixels) / 48)
    @floatPercent(player, slot, deltaPercent)
    if @skip? then done() else setTimeout(done, 500)

  floatPercent: (player, slot, percent) =>
    return  if @skip?
    $sprite = @$sprite(player, slot)
    [x, y] = @getPokemonPosition(player, slot)
    kind = (if percent >= 0 then "" else "red")
    percentText = "#{percent}"
    percentText = "+#{percentText}"  if percent >= 0
    percentText += "%"
    $hp = $('<span/>').addClass("percentage #{kind}").text(percentText)
    $hp.hide().appendTo(@$('.battle_pane'))
    x -= $hp.width() / 2
    y -= $sprite.height() / 3
    $hp.css(position: 'absolute', top: y, left: x).show()
    if percent >= 0
      $hp.transition(top: "-=30", 1000, 'easeOutCubic')
      $hp.delay(1000)
      $hp.transition(opacity: 0, 1000, -> $hp.remove())
    else
      $hp.transition(top: "+=30", 1000, 'easeOutCubic')
      $hp.delay(1000)
      $hp.transition(opacity: 0, 1000, -> $hp.remove())

  switchIn: (player, slot, fromSlot, done) =>
    $oldPokemon = @$pokemon(player, slot)
    $newPokemon = @$pokemon(player, fromSlot)
    $newSprite = @$sprite(player, fromSlot)
    pokemon = @model.getPokemon(player, slot)
    @renderUserInfo()

    # Prepare old/new pokemon
    $oldPokemon.attr('data-slot', fromSlot)
    $newPokemon.attr('data-slot', slot)
    $newPokemon.removeClass('hidden')
    @popover($newSprite, pokemon)

    if @skip?
      $oldPokemon.css(opacity: 0)
      $newPokemon.css(opacity: 1)
      done()
      return

    # Create and position pokeball
    pos = $newSprite.position()
    x = pos.left + $newSprite.width() / 2 - 11
    y = pos.top + $newSprite.height() / 3
    $pokeball = @makePokeball(x, y)
    $pokeball.css(opacity: 0)
    $pokeball.appendTo(@$(".battle_pane"))

    # Start animations
    $oldPokemon.css(opacity: 0)
    $newPokemon.css(opacity: 0)
    $pokeball.css(opacity: 1)
    releasePokemon = =>
      $pokeball.css(opacity: 0)
      $newSprite
        .transition(y: -15, scale: .1, 0)
        .transition(scale: 1, 250)
        .transition y: 0, 250, 'out', =>
          @removePokeball($pokeball)
          done()
      $newPokemon.transition(opacity: 1)
    setTimeout(releasePokemon, 250)

  switchOut: (player, slot, done) =>
    $pokemon = @$pokemon(player, slot)
    $sprite = @$sprite(player, slot)

    if @skip?
      $pokemon.addClass('hidden')
      $sprite.popover('destroy')
      done()
      return

    width = $sprite.width()
    height = $sprite.height()
    $sprite.transition(scale: 0.1, x: width >> 1, y: height, 150)
    $pokemon.transition opacity: 0, 250, ->
      $pokemon.addClass('hidden').css(opacity: 1)
      $sprite.popover('destroy')
      $sprite.transition(scale: 1, x: 0, y: 0, 0)
      done()

  makePokeball: (x, y) =>
    $pokeball = $("""<div class="pokeball"/>""")
    $pokeball.css(top: y, left: x)
    size = 22
    $pokeball.width(size).height(size)
    func = ->
      $pokeball.css(backgroundPositionY: -10 - func.counter * 40)
      func.counter = (func.counter + 1) % 8
    func.counter = 1
    id = setInterval(func, 40)
    $pokeball.data('animation-id', id)
    $pokeball

  removePokeball: ($pokeball) =>
    id = $pokeball.data('animation-id')
    clearTimeout(id)
    $pokeball.remove()

  logMove: (player, slot, moveName, done) =>
    {owner} = @model.getTeam(player)
    pokemon = @model.getPokemon(player, slot)
    @addMoveMessage(owner, pokemon, moveName)
    @lastMove = moveName
    done()

  moveSuccess: (player, slot, targetSlots, moveName, done) =>
    return done()  if @skip?

    gen = @model.get('generation').toUpperCase()
    moveData = window.Generations[gen]?.MoveData[moveName]
    if !moveData
      console.error("Could not display animation for #{moveName} as it does not
        exist in #{gen}.")
      done()
      return

    [targetPlayer, targetSlot] = targetSlots[0]
    $attacker = @$sprite(player, slot)
    $defender = @$sprite(targetPlayer, targetSlot)
    [a, d] = [$attacker.position(), $defender.position()]
    front = (a.top < d.top)
    scale = (if front then 1.3 else 1/1.3)
    if moveName == 'Earthquake'
      $attacker.add($defender).each (index) ->
        callback = (if index == 0 then done else undefined)
        $(this).transition(x: -75, 62.5, 'easeInOutCubic')
          .transition(x: 75, 125, 'easeInOutCubic')
          .transition(x: -30, 125, 'easeInOutCubic')
          .transition(x: 30, 125, 'easeInOutCubic')
          .transition(x: 0, 62.5, 'easeInOutCubic', callback)
    else if 'contact' in moveData.flags
      # Simple attack animation
      # Tackling the opponent
      $attacker
        .transition(x: d.left - a.left, y: d.top - a.top, scale: scale, 250, 'in')
        .transition(x: 0, y: 0, scale: 1, 250, 'out')
      $defender.delay(400)
        .transition(x: (if front then -16 else 8), 50, 'easeOutCubic')
        .transition(x: 0, 50, 'easeInOutCubic', done)
    else if moveData['power'] > 0
      # Non-contact attacking move
      # Projectile
      $projectile = @$projectile($attacker, moveData)
      [transX, transY] = [(d.left - a.left), (d.top - a.top)]
      $projectile
        .transition(x: transX / 2, y: transY / 2, scale: (scale + 1) / 2, 200, 'easeOutCubic')
        .transition(x: transX, y: transY, scale: scale, 200, 'easeOutCubic')
        .transition(opacity: 0, 100, -> $projectile.remove())
      $defender.delay(400)
        .transition(x: -4, 0, 'linear').delay(50)
        .transition(x: 4, 0, 'linear').delay(50)
        .transition(x: 0, 0, 'linear', done)
    else if player != targetPlayer || slot != targetSlot
      # This is a non-attacking move that affects another pokemon
      # S-shaped movement
      $projectile = @$projectile($attacker, moveData)
      [transX, transY] = [(d.left - a.left), (d.top - a.top)]
      $projectile
        .transition(x: transX * 2 / 3, y: transY / 3, 150, 'easeInOutSine')
        .transition(x: transX / 3, y: transY * 2 / 3, 100, 'easeInOutSine')
        .transition(x: transX, y: transY, 150, 'easeInOutSine')
        .transition opacity: 0, 100, 'easeInOutSine', ->
          $projectile.remove()
          done()
    else
      # Side-to-side movement
      $attacker = @$sprite(player, slot)
      $attacker
        .transition(x: -16, 125, 'easeInOutSine')
        .transition(x: 16, 250, 'easeInOutSine')
        .transition(x: 0, 125, 'easeInOutSine', done)

  cannedText: (cannedInteger, args, done) =>
    cannedTextName = CannedMapReverse[cannedInteger]
    cannedText = @getCannedText(cannedTextName, args)
    @addLog(cannedText)
    @actOnCannedText(cannedTextName, cannedText, done)

  # Some canned text requires special actions.
  # For example, misses require a delay, and also prints to the battle pane.
  actOnCannedText: (cannedTextName, cannedText, done) =>
    switch cannedTextName
      when 'MOVE_MISS', 'MOVE_FAIL', 'IMMUNITY'
        @addSummary(cannedText)
        setTimeout(done, 500)
      when 'GOT_HIT', 'CRITICAL_HIT', 'SUPER_EFFECTIVE', 'NOT_VERY_EFFECTIVE'
        @addSummary(cannedText)
        done()
      else
        done()

  getCannedText: (cannedTextName, args) =>
    cannedText = 'Please refresh to see this text!'
    genIndex   = ALL_GENERATIONS.indexOf(@model.get('generation'))
    language   = 'en'
    # Run through inheritance chain of generations to find the canned text
    for i in [genIndex..0] by -1
      generation = ALL_GENERATIONS[i]
      if CannedMap[generation]?[language]?[cannedTextName]
        cannedText = CannedMap[generation][language][cannedTextName]
        break
    # Replace special characters in the canned text with the arguments
    cannedText.replace /\$([a-z]|\d+)/g, (match, p1) =>
      switch p1
        when 'p'
          [player, slot] = args.splice(0, 2)
          pokemon = @model.getPokemon(player, slot)
          pokemon.get('name')
        when 't'
          [player] = args.splice(0, 1)
          @model.getTeam(player).owner
        else
          [text] = args.splice(0, 1)
          text

  activateAbility: (player, slot, abilityName, done) =>
    return done()  if @skip?

    pokemon = @model.getPokemon(player, slot)
    isFront = @isFront(player)
    $ability = $('<div/>').addClass('ability_activation')
    $ability.html("#{pokemon.get('name')}'s <strong>#{abilityName}</strong>")
    $ability.addClass((if isFront then 'front' else 'back'))
    $ability.width(1)
    $ability.appendTo(@$('.battle_pane'))
    $ability.transition opacity: 1, width: 150, 100, 'easeInQuad', ->
      setTimeout(done, 400)
      $ability.delay(3000).transition opacity: 0, 300, 'easeInQuad', ->
        $ability.remove()

  cancelSuccess: (done) =>
    @enableButtons()
    done()

  changeSprite: (player, slot, species, forme, done) =>
    $spriteContainer = @$spriteContainer(player, slot)
    $sprite = @$sprite(player, slot)
    $spriteContainer.data('name', species)
    $spriteContainer.data('forme', forme)

    if @skip?
      @renderPokemon $spriteContainer, ->
        $sprite.remove()
      done()
      return

    $sprite.fadeOut =>
      $sprite.remove()
      @renderPokemon $spriteContainer, ($image) ->
        $image.hide().fadeIn(done)

  changeWeather: (newWeather, done) =>
    $overlays = @$('.battle_overlays')
    $overlays.find('.weather').animate(opacity: 0, 500, -> $(this).remove())
    $weather = switch newWeather
      when Weather.RAIN
        $overlays.append($("<div/>").addClass("battle_overlay weather rain"))
      when Weather.SUN
        $overlays.append($("<div/>").addClass("battle_overlay weather sun"))
      when Weather.SAND
        $overlays.append($("<div/>").addClass("battle_overlay weather sand"))
      when Weather.HAIL
        $overlays.append($("<div/>").addClass("battle_overlay weather hail"))
      else $()
    $weather.css(opacity: 0).animate(opacity: 1, 500)
    done()

  attachPokemon: (player, slot, attachment, done) =>
    pokemon = @model.getPokemon(player, slot)
    $pokemon = @$pokemon(player, slot)
    switch attachment
      when 'SubstituteAttachment'
        $spriteContainer = @$spriteContainer(player, slot)
        $spriteContainer.addClass('fade')
        substituteUrl = (if @isFront(player) then "substitute" else "subback")
        substituteUrl = "http://sprites.pokecheck.org/o/#{substituteUrl}.gif"
        @addPokemonImage $pokemon, substituteUrl, callback: ($image) =>
          [x, y] = @getPokemonPosition(player, slot)
          $image.addClass('substitute')
          width = $image.width()
          height = $image.height()
          x -= (width >> 1)
          y -= (height >> 1)
          yOffset = 200
          $image.css(position: 'absolute', left: x, top: y)
          $image.show()
          return done()  if @skip?
          setTimeout ->
            $image
              .transition(y: -yOffset, 0)
              .transition(y: 0, 200, 'easeInQuad')
              .transition(y: -yOffset >> 3, 100, 'easeOutQuad')
              .transition(y: 0, 100, 'easeInQuad', done)
          , 0
      when 'ConfusionAttachment'
        @addPokemonEffect($pokemon, "confusion", "Confusion")
        @addLog("#{pokemon.get('name')} became confused!")
        done()
      when 'Air Balloon'
        @addPokemonEffect($pokemon, "balloon", "Balloon")
        @addLog("#{pokemon.get('name')} floats in the air with its Air Balloon!")
        done()
      when 'Paralyze'
        pokemon.set('status', 'paralyze')
        done()
      when 'Burn'
        pokemon.set('status', 'burn')
        done()
      when 'Poison'
        pokemon.set('status', 'poison')
        done()
      when 'Toxic'
        pokemon.set('status', 'toxic')
        done()
      when 'Freeze'
        pokemon.set('status', 'freeze')
        done()
      when 'Sleep'
        pokemon.set('status', 'sleep')
        done()
      else
        done()

  attachTeam: (player, attachment, done) =>
    $battlePane = @$('.battle_pane')
    isFront = @isFront(player)
    switch attachment
      when "StealthRockAttachment"
        $div = $("<div/>").addClass("field-#{player} team-stealth-rock")
        if isFront
          [ oldX, oldY ] = [ "20%", "80%" ]
          [ newX, newY ] = [ "67%", "45%" ]
        else
          [ oldX, oldY ] = [ "80%", "20%" ]
          [ newX, newY ] = [ "34%", "81%" ]
        if @skip?
          $div.css(top: newY, left: newX, opacity: .5)
          $battlePane.prepend($div)
          done()
        else
          $div.css(top: oldY, left: oldX, opacity: 0)
          $div.animate(top: newY, left: newX, opacity: 1, 500)
            .delay(1000).animate(opacity: .5)
          $battlePane.prepend($div)
          setTimeout(done, 500)
      when "ToxicSpikesAttachment"
        $div = $("<div/>").addClass("field-#{player} team-toxic-spikes")
        previousLayers = @$(".field-#{player}.team-toxic-spikes").length
        if isFront
          oldY = "80%"
          oldX = "20%"
          newY = switch previousLayers
            when 0 then "51%"
            when 1 then "50%"
          newX = switch previousLayers
            when 0 then "77%"
            when 1 then "73%"
        else
          oldY = "30%"
          oldX = "80%"
          newY = switch previousLayers
            when 0 then "87%"
            when 1 then "86%"
          newX = switch previousLayers
            when 0 then "23%"
            when 1 then "27%"
        if @skip?
          $div.css(top: newY, left: newX, opacity: .5)
          $battlePane.prepend($div)
          done()
        else
          $div.css(top: oldY, left: oldX, opacity: 0)
          $div.animate(top: newY, left: newX, opacity: 1, 500)
            .delay(1000).animate(opacity: .5)
          $battlePane.prepend($div)
          setTimeout(done, 500)
      when "SpikesAttachment"
        $div = $("<div/>").addClass("field-#{player} team-spikes")
        previousLayers = @$(".field-#{player}.team-spikes").length
        if isFront
          oldY = "80%"
          oldX = "20%"
          newY = switch previousLayers
            when 0 then "49%"
            when 1 then "52%"
            when 2 then "50%"
          newX = switch previousLayers
            when 0 then "87%"
            when 1 then "84%"
            when 2 then "82%"
        else
          oldY = "30%"
          oldX = "80%"
          newY = switch previousLayers
            when 0 then "85%"
            when 1 then "88%"
            when 2 then "86%"
          newX = switch previousLayers
            when 0 then "13%"
            when 1 then "16%"
            when 2 then "18%"
        if @skip?
          $div.css(top: newY, left: newX, opacity: .5)
          $battlePane.prepend($div)
          done()
        else
          $div.css(top: oldY, left: oldX, opacity: 0)
          $div.animate(top: newY, left: newX, opacity: 1, 500)
            .delay(1000).animate(opacity: .5)
          $battlePane.prepend($div)
          setTimeout(done, 500)
      when "StickyWebAttachment"
        $div = $("<div/>").addClass("field-#{player} team-sticky-web")
        if isFront
          [ oldX, oldY ] = [ "0%",  "50%" ]
          [ newX, newY ] = [ "65%", "10%"  ]
        else
          [ oldX, oldY ] = [ "65%", "10%"  ]
          [ newX, newY ] = [ "0%",  "50%" ]
        if @skip?
          $div.css(top: newY, left: newX, opacity: .5)
          $battlePane.prepend($div)
          done()
        else
          $div.css(top: oldY, left: oldX, opacity: 0)
          $div.animate(top: newY, left: newX, opacity: 1, 1000, 'easeOutElastic')
            .delay(1000).animate(opacity: .2)
          $battlePane.prepend($div)
          setTimeout(done, 500)
      else
        done()

  attachBattle: (attachment, done) =>
    done()

  boost: (player, slot, deltaBoosts, done) =>
    pokemon = @model.getPokemon(player, slot)
    pokemonName = pokemon.get('name')
    stages = pokemon.get('stages')
    $pokemon = @$pokemon(player, slot)
    $effects = $pokemon.find('.pokemon-effects')
    for stat, delta of deltaBoosts
      previous = stages[stat]
      stages[stat] += delta
      # Boost log message
      message = @makeBoostMessage(pokemonName, stat, delta, stages[stat])
      @addLog(message)  if message
      # Boost in the view
      abbreviatedStat = switch stat
        when "attack" then "Att"
        when "defense" then "Def"
        when "speed" then "Spe"
        when "specialAttack" then "Sp.A"
        when "specialDefense" then "Sp.D"
        when "accuracy" then "Acc."
        when "evasion" then "Eva."
        else stat
      amount = stages[stat]
      amount = "+#{amount}"  if amount > 0
      abbreviatedStat = "#{amount} #{abbreviatedStat}"
      $effect = @addPokemonEffect($pokemon, "boost #{stat}", abbreviatedStat)
      if amount < 0
        $effect.addClass('negative')
      else if amount > 0
        $effect.removeClass('negative')
      else # amount == 0
        $effect.remove()
    done()
    true

  makeBoostMessage: (pokemonName, stat, amount, currentBoost) ->
    stat = switch stat
      when "attack" then "Attack"
      when "defense" then "Defense"
      when "speed" then "Speed"
      when "specialAttack" then "Special Attack"
      when "specialDefense" then "Special Defense"
      when "accuracy" then "Accuracy"
      when "evasion" then "Evasion"
      else stat
    if amount > 0
      if amount == 12
        "#{pokemonName} cut its own HP and maximized its #{stat}!"
      else
        adverb = ""              if amount == 1
        adverb = " sharply"      if amount == 2
        adverb = " drastically"  if amount >= 3
        "#{pokemonName}'s #{stat} rose#{adverb}!"
    else if amount < 0
      adverb = ""           if amount == -1
      adverb = " harshly"   if amount == -2
      adverb = " severely"  if amount <= -3
      "#{pokemonName}'s #{stat}#{adverb} fell!"
    else if currentBoost == 6
      "#{pokemonName}'s #{stat} won't go any higher!"
    else if currentBoost == -6
      "#{pokemonName}'s #{stat} won't go any lower!"

  unattachPokemon: (player, slot, effect, done) =>
    pokemon = @model.getPokemon(player, slot)
    $pokemon = @$pokemon(player, slot)
    switch effect
      when 'SubstituteAttachment'
        $spriteContainer = @$spriteContainer(player, slot)
        $spriteContainer.removeClass('fade')
        $substitute = $pokemon.find('.substitute').first()

        if @skip?
          $substitute.remove()
          done()
        else
          $substitute.transition y: 300, opacity: 0, ->
            $substitute.remove()
            done()
      when 'Air Balloon'
        $pokemon.find(".pokemon-effect.balloon").remove()
        @addLog("#{pokemon.get('name')}'s Air Balloon popped!")
        done()
      when 'ConfusionAttachment'
        $pokemon.find(".pokemon-effect.confusion").remove()
        done()
      when 'Paralyze'
        pokemon.set('status', null)
        done()
      when 'Burn'
        pokemon.set('status', null)
        done()
      when 'Poison'
        pokemon.set('status', null)
        done()
      when 'Toxic'
        pokemon.set('status', null)
        done()
      when 'Freeze'
        pokemon.set('status', null)
        done()
      when 'Sleep'
        pokemon.set('status', null)
        done()
      else
        done()

  resetBoosts: (player, slot, done) =>
    pokemon = @model.getPokemon(player, slot)
    pokemon.resetBoosts()
    $pokemon = @$pokemon(player, slot)
    $pokemon.find('.boost').remove()
    done()

  handleStatus: (pokemon, status) =>
    $pokemon = @$pokemon(pokemon)
    if status?
      $effects = $pokemon.find('.pokemon-effects')
      display = @mapStatusForDisplay(status)
      @addPokemonEffect($pokemon, status, display)
    else
      $pokemon.find(".pokemon-effect.#{pokemon.previous('status')}").remove()

  mapStatusForDisplay: (status) =>
    switch status
      when "burn" then "BRN"
      when "paralyze" then "PAR"
      when "poison" then "PSN"
      when "toxic" then "TOX"
      when "freeze" then "FRZ"
      when "sleep" then "SLP"

  addPokemonEffect: ($pokemon, klass, text) =>
    $effects = $pokemon.find(".pokemon-effects")
    $effect = $effects.find(".pokemon-effect.#{klass.replace(/\s+/g, '.')}")
    return $effect  if !text
    if $effect.length == 0
      $effect = $("<div class='pokemon-effect #{klass}'>#{text}</div>")
      $effect.appendTo($effects)
    else
      $effect.text(text)
    $effect

  unattachTeam: (player, attachment, done) =>
    $battlePane = @$('.battle_pane')
    switch attachment
      when "StealthRockAttachment"
        $battlePane.find(".field-#{player}.team-stealth-rock").remove()
        done()
      when "ToxicSpikesAttachment"
        $battlePane.find(".field-#{player}.team-toxic-spikes").remove()
        done()
      when "SpikesAttachment"
        $battlePane.find(".field-#{player}.team-spikes").remove()
        done()
      when "StickyWebAttachment"
        $battlePane.find(".field-#{player}.team-sticky-web").remove()
        done()
      else
        done()

  unattachBattle: (effect, done) =>
    done()

  updateTimers: (timers, done) =>
    @timers = timers
    done()

  renderTimers: =>
    $userInfo = @$('.battle_user_info')
    $yourTimer = $userInfo.find('.left .battle-timer')
    $theirTimer = $userInfo.find('.right .battle-timer')
    yourIndex = @model.index
    theirIndex = (1 - yourIndex)
    now = $.now()
    yourTime = @timerFrozenAt[yourIndex] || (@timers[yourIndex] - now)
    theirTime = @timerFrozenAt[theirIndex] || (@timers[theirIndex] - now)
    if yourTime && theirTime
      @changeTimer($yourTimer, yourTime)
      @changeTimer($theirTimer, theirTime)

  countdownTimers: =>
    @renderTimers()
    now = $.now()
    keepRunning = (Math.min(@timers...) - now) > 0
    return  if !keepRunning
    diff = ($.now() - @battleStartTime - @timerIterations * 1000)
    @timerIterations++
    @countdownTimersId = setTimeout(@countdownTimers, 1000 - diff)

  changeTimer: ($timer, timeRemaining) =>
    timeRemaining = 0  if timeRemaining < 0
    $timer.text PokeBattle.humanizeTime(timeRemaining)
    if timeRemaining <= 1 * 60 * 1000
      $timer.addClass("battle-timer-low")
    else
      $timer.removeClass("battle-timer-low")

  pauseTimer: (index) =>
    @timerFrozenAt[index] = @timers[index] - $.now()

  resumeTimer: (index) =>
    delete @timerFrozenAt[index]

  announceWinner: (player, done) =>
    {owner} = @model.getTeam(player)
    message = "#{owner} won!"
    @announceWin(message, done)

  announceForfeit: (player, done) =>
    {owner} = @model.getTeam(player)
    message = "#{owner} has forfeited!"
    @announceWin(message, done)

  announceTimer: (player, done) =>
    {owner} = @model.getTeam(player)
    message = "#{owner} was given the timer win!"
    @announceWin(message, done)

  announceWin: (message, done) =>
    @chatView.print("<h3>#{message}</h3>")
    @addSummary(message, newline: true)
    @model.set('finished', true)
    done()

  handleEnd: (battle, end) =>
    @disableButtons()
    @$('.battle_actions').html """
    <div class="button big save-log">Save Log</div>
    """
    clearTimeout(@countdownTimersId)

  saveLog: =>
    log = []
    $children = @$('.messages').children()
    $children.each ->
      $this = $(this)
      isHeader = /H\d/i.test(@tagName)
      log.push ""  if isHeader
      log.push $this.text()
      log.push ""  if isHeader
    log = [ log.join('\n') ]
    fileName = (team.owner  for team in @model.teams).join(" vs ")
    fileName += ".txt"
    blob = new Blob(log, type: "text/plain;charset=utf-8", endings: "native")
    saveAs(blob, fileName)

  $pokemon: (player, slot) =>
    if arguments.length == 1
      pokemon = player
      for team, i in @model.teams
        index = team.indexOf(pokemon)
        if index != -1
          player = i
          slot = index
          break
    @$(".pokemon[data-team='#{player}'][data-slot='#{slot}']")

  $spriteContainer: (player, slot) =>
    @$pokemon(player, slot).find('.sprite')

  $sprite: (player, slot) =>
    @$spriteContainer(player, slot).find('img')

  $projectile: ($pokemon, moveData) =>
    $projectile = $('<div/>').addClass('projectile')
    $projectile.addClass(moveData['type'].toLowerCase())
    $projectile.appendTo(@$(".battle_pane"))
    pos = $pokemon.position()
    $projectile.css(
      top: pos.top + (($pokemon.height() - $projectile.height()) >> 1)
      left: pos.left + (($pokemon.width() - $projectile.width()) >> 1)
    )
    $projectile

  isFront: (player) =>
    @model.index != player

  faint: (player, slot, done) =>
    $pokemon = @$pokemon(player, slot)
    $sprite = @$sprite(player, slot)

    if @skip?
      $sprite.popover('destroy')
      $sprite.remove()
      done()
      return

    $sprite.transition y: 100, opacity: 0, 250, 'ease-in', ->
      $sprite.popover('destroy')
      $sprite.remove()
      done()
    @renderUserInfo()

  resetPopovers: =>
    return  if !@model.teams
    for player in [0...2]
      for slot in [0...@model.numActive]
        $pokemon = @$pokemon(player, slot)
        pokemon = @model.getPokemon(player, slot)
        $sprite = @$sprite(player, slot)
        $sprite.popover('destroy')
        @popover($sprite, pokemon)

  enableButtons: (validActions) =>
    @lastValidActions = validActions || @lastValidActions
    @renderActions(@lastValidActions)
    @resumeTimer(@model.index)

  disableButtons: =>
    @$('.battle_actions .switch.button').popover('destroy')
    @renderWaiting()
    @pauseTimer(@model.index)

  addMoveMessage: (owner, pokemon, moveName) =>
    @chatView.print("<p class='move_message'>#{owner}'s #{pokemonHtml(pokemon)} used <strong>#{moveName}</strong>!</p>")
    @addSummary("#{owner}'s #{pokemon.get('name')} used <strong>#{moveName}</strong>!", newline: true)

  addLog: (message) =>
    @chatView.print("<p>#{message}</p>")

  addSummary: (message, options = {}) =>
    return  if @skip?
    $summary = @$('.battle_summary')
    $summary.show()
    $p = $summary.children().last()
    if $p.length == 0 || $p.is('.newline') || options.newline
      $p = $("<p/>").html(message).hide()
      $p.addClass('newline')  if options.newline
      $p.appendTo($summary)
    else
      html = $p.html()
      $p.html("#{html} #{message}")
    $p.slideDown(200)

  beginTurn: (turn, done) =>
    @chatView.print("<h2>Turn #{turn}</h2>")
    @model.set('turn', turn)
    done()

  continueTurn: (done) =>
    $battleWindow = @$el.closest('.battle_window')
    @$('.battle_summary').empty().hide()
    offset = @$('.battle_pane').offset().top + $battleWindow.scrollTop()
    offset -= $battleWindow.offset().top
    $battleWindow.scrollTop(offset)
    done()

  makeMove: (e) =>
    $target = $(e.currentTarget)
    moveName = $target.data('move-id')
    if $target.hasClass('disabled')
      console.log "Cannot use #{moveName}."
      return
    console.log "Making move #{moveName}"
    @model.makeMove(moveName)
    @disableButtons()

  switchPokemon: (e) =>
    $target = $(e.currentTarget)
    toSlot = $target.data('slot')
    if $target.hasClass('disabled')
      console.log "Cannot switch to #{toSlot}."
      return
    console.log "Switching to #{toSlot}"
    toSlot = parseInt(toSlot, 10)
    @model.makeSwitch(toSlot)
    @disableButtons()

  cancelAction: (e) =>
    @$('.battle_actions').html """
    <div class="well well-battle-actions">Canceling...</div>
    """

    @model.makeCancel()

  megaEvolve: (e) =>
    $target = $(e.currentTarget)
    $target.toggleClass('pressed')
    pokemon = @model.getPokemon(@model.index, 0)
    pokemon.set('megaEvolve', $target.hasClass("pressed"))

  preloadImages: =>
    front = @isFront(@model.index)
    gen   = window.Generations[@model.get('generation').toUpperCase()]
    teams = _.map @model.teams, (team) ->
      for pokemon in team.models
        name  = pokemon.get('name')
        forme = pokemon.get('forme')
        shiny = pokemon.get('shiny')
        {id}  = gen.SpeciesData[name]
        formes = gen.FormeData[name]
        formeNames = _.keys(formes)
        formeNames = _.filter formeNames, (formeName) ->
          forme == formeName || formes[forme].isBattleOnly
        for formeName in formeNames
          PokemonSprite(id, formeName, front: front, shiny: shiny)
    pokemonUrls = _.flatten(teams)
    for pokemonUrl in pokemonUrls
      image = new Image()
      image.src = pokemonUrl

  addPokemonImage: ($div, url, options = {}) =>
    scale = options.scale || 1
    image = new Image()
    $image = $(image)
    $image.load =>
      {width, height} = image
      if scale != 1
        width  *= scale
        height *= scale
        $image.width(width)
        $image.height(height)
      options.callback?($image)
    image.src = url
    $image.hide().appendTo($div)

  getPokemonPosition: (player, slot) =>
    if player == @model.index
      [96, 208]
    else
      [332, 108]

pokemonHtml = (pokemon) ->
  "<a class='pokemon-link' href='#{pokemon.getPokedexUrl()}' target='_blank'>#{pokemon.get('name')}</a>"
