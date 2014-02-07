class @BattleView extends Backbone.View
  battle_template: JST['battle']
  pokemon_template: JST['battle_pokemon']
  user_info_template: JST['battle_user_info']
  action_template: JST['battle_actions']
  team_preview_template: JST['battle_team_preview']

  events:
    'click .move': 'makeMove'
    'click .switch': 'switchPokemon'
    'click .mega-evolve': 'megaEvolve'
    'click .cancel': 'cancelAction'
    'click .submit_arrangement': 'submitTeamPreview'
    'click .save-log': 'saveLog'

  initialize: =>
    @selected = null
    @chatView = null
    @lastMove = null
    @skip     = null
    @renderChat()
    @listenTo(@model, 'team_preview', @renderTeamPreview)
    @listenTo(@model, 'change:status', @handleStatus)
    @listenTo(@model, 'change:finished', @handleEnd)

  renderBattle: =>
    locals =
      yourTeam     : @model.getTeam()
      opponentTeam : @model.getOpponentTeam()
      numActive    : @model.numActive
      yourIndex    : @model.index
      window       : window
    @$('.battle_pane').html @battle_template(locals)
    @addImages()
    this

  renderChat: =>
    @chatView = new ChatView(
      el: @$('.chat')
      collection: @model.spectators
      chatEvent: 'send battle chat'
      chatArgs: [ @model.id ]
    ).render().renderUserList()
    this

  # TODO: Support 2v2
  renderActions: (validActions) =>
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

  renderTeamPreview: (teams) =>
    locals =
      teams        : teams
      numActive    : @model.numActive
      yourIndex    : @model.index
      isSpectating : @model.get('spectating')
      window       : window
    @$('.battle_pane').html @team_preview_template(locals)
    $arrangeTeam = @$('.arrange_team')
    $arrangeTeam.sortable()
    $arrangeTeam.on 'sortupdateplaceholder', (e, $placeholder) ->
      $visible = $arrangeTeam.children(":visible")
      $first = $visible.first()
      $first.addClass('first-child')
      $visible.not($first).removeClass('first-child')

  submitTeamPreview: (e) =>
    $currentTarget = $(e.currentTarget)
    return  if $currentTarget.hasClass('disabled')
    $currentTarget.addClass('disabled')
    $teamPreview = @$('.battle_teams')
    indices = for element in @$('.arrange_team .pokemon_icon')
      $(element).data('index')
    @model.arrangeTeam(indices)
    move($teamPreview)
      .set('opacity', 0).duration('.25s')
      .end(=> @removeTeamPreview())

  removeTeamPreview: =>
    $teamPreview = @$('.battle_teams')
    $teamPreview.remove()

  addImages: ($images, callback) =>
    $images ||= @$('.preload')
    battle = @model
    $images.each ->
      $this = $(this)
      front = $this.closest('.pokemon').hasClass('top')
      name  = $this.data('name')
      forme = $this.data('forme')
      shiny = $this.data('shiny')
      gen   = battle.get('generation').toUpperCase()
      {id}  = window.Generations[gen].SpeciesData[name]
      url   = PokemonSprite(id, forme, front: front, shiny: shiny)
      scale = if front then 1 else 2
      addPokemonImage($this, url, scale: scale, callback: callback)

  changeHP: (player, slot, oldPixels, done) =>
    $pokemon = @$pokemon(player, slot)
    $info = $pokemon.find(".pokemon-info")
    $hp = $info.find('.hp')
    $allHP = $info.find('.hp, .hp-red')
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
    done()

  floatPercent: (player, slot, percent) =>
    return  if @skip?
    $sprite = @$sprite(player, slot)
    kind = (if percent >= 0 then "success" else "important")
    $hp = $('<span/>').addClass("label label-#{kind}").text("#{percent}%")
    $hp.hide().appendTo($sprite)
    x = $sprite.width() / 2 - $hp.width()
    y = $sprite.height() / 3
    $hp.css(position: 'absolute', top: y, left: x).show()
    move($hp).y(-30).ease('ease-out').duration('1s')
      .then().delay('3s').set('opacity', 0).pop()
      .end(-> $hp.remove())

  switchIn: (player, slot, fromSlot, done) =>
    $oldPokemon = @$pokemon(player, slot)
    $newPokemon = @$pokemon(player, fromSlot)
    pokemon = @model.getPokemon(player, slot)
    @renderUserInfo()

    # Prepare old/new pokemon
    $oldPokemon.attr('data-slot', fromSlot)
    $newPokemon.attr('data-slot', slot)
    $newPokemon.removeClass('hidden')
    $newSprite = $newPokemon.find('.sprite')
    @popover($newSprite, pokemon)

    if @skip?
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
    $newPokemon.css(opacity: 0)
    $pokeball.css(opacity: 1)
    releasePokemon = =>
      $pokeball.css(opacity: 0)
      move($newSprite)
        .y(-15).scale(.1).duration(0).then()
        .scale(10).duration('.25s').then()
        .y(15).duration('.25s').ease('ease-out').pop().pop().end =>
          @removePokeball($pokeball)
          done()
      move($newPokemon).set('opacity', 1).end()
    setTimeout(releasePokemon, 250)

  switchOut: (player, slot, done) =>
    $pokemon = @$pokemon(player, slot)

    if @skip?
      $pokemon.addClass('hidden')
      done()
      return

    $sprite = $pokemon.find('.sprite')
    width = $sprite.width()
    height = $sprite.height()
    move($sprite).scale(0.1).x(width / 2).y(height).duration('.15s').end()
    move($pokemon).set('opacity', 0).duration('.25s').end ->
      $pokemon.addClass('hidden').css(opacity: 1)
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

  moveSuccess: (player, slot, targetSlot, done) =>
    done()

  cancelSuccess: =>
    @enableButtons()
    done()

  changeSprite: (player, slot, species, forme) =>
    self = this
    $sprite = @$sprite(player, slot)
    $sprite.find('img').fadeOut ->
      $(this).remove()
      $sprite.data('name', species)
      $sprite.data('forme', forme)
      self.addImages($sprite, ($image) -> $image.hide().fadeIn())

  attachPokemon: (player, slot, attachment, done) =>
    pokemon = @model.getPokemon(player, slot)
    switch attachment
      when 'SubstituteAttachment'
        $pokemon = @$pokemon(player, slot)
        $sprite = @$sprite(player, slot)
        spriteWidth = $sprite.width()
        spriteHeight = $sprite.height()
        $sprite.addClass('fade')
        position = $sprite.position()
        substituteUrl = (if @isFront(player) then "substitute" else "subback")
        substituteUrl = "http://sprites.pokecheck.org/o/#{substituteUrl}.gif"
        addPokemonImage $pokemon, substituteUrl, callback: ($image) ->
          $image.addClass('substitute')
          width = $image.width()
          height = $image.height()
          x = position.left + ((spriteWidth - width) >> 1)
          y = position.top + ((spriteHeight - height) >> 1)
          yOffset = 200
          $image.remove()
          $image.css(left: x, top: y - yOffset)
          $image.appendTo($pokemon)
          setTimeout ->
            move($image)
              .y( yOffset).ease('ease-in-quad').duration(@skip ? '.2s').then()
              .y(-yOffset >> 3).ease('ease-out-quad').duration(@skip ? '.1s').then()
              .y( yOffset >> 3).ease('ease-in-quad').duration(@skip ? '.1s').then()
              .pop().pop().pop().end(done)
          , 0
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
    switch effect
      when 'SubstituteAttachment'
        $pokemon = @$pokemon(player, slot)
        $sprite = @$sprite(player, slot)
        $sprite.removeClass('fade')
        $substitute = $pokemon.find('.substitute').first()

        if @skip?
          $substitute.remove()
          done()
        else
          move($substitute).set('opacity', 0).y(300)
            .then(-> $substitute.remove()).end(done)
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

  unattachTeam: (slot, effect, done) =>
    done()

  unattachBattle: (effect, done) =>
    done()

  announceWinner: (player, done) =>
    {owner} = @model.getTeam(player)
    @chatView.print("<h3>#{owner} won!</h3>")
    @model.set('finished', true)
    done()

  announceForfeit: (player, done) =>
    {owner} = @model.getTeam(player)
    @chatView.print("<h3>#{owner} has forfeited!</h3>")
    @model.set('finished', true)
    done()

  handleEnd: (battle, end) =>
    @disableButtons()
    @$('.battle_actions').html """
    <div class="button big save-log">Save Log</div>
    """

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

  $sprite: (player, slot) =>
    @$pokemon(player, slot).find('.sprite')

  isFront: (player) =>
    @model.index != player

  faint: (player, slot, done) =>
    $pokemon = @$pokemon(player, slot)

    if @skip?
      $pokemon.addClass('hidden')
      done()
      return

    $image = $pokemon.find('.sprite img')
    move($image).set('top', '100%').duration('.25s').ease('ease-in').end()
    move($pokemon).set('opacity', 0).end ->
      $pokemon.addClass('hidden').css(opacity: 1)
      done()
    @renderUserInfo()

  enableButtons: (validActions) =>
    @lastValidActions = validActions || @lastValidActions
    @renderActions(@lastValidActions)

  disableButtons: =>
    @$('.battle_actions .switch.button').popover('destroy')
    @renderWaiting()

  addMoveMessage: (owner, pokemon, moveName) =>
    @chatView.print("<p class='move_message'>#{owner}'s #{pokemon.get('name')}
      used <strong>#{moveName}</strong>!</p>")

  addLog: (message) =>
    @chatView.print("<p>#{message}</p>")

  beginTurn: (turn, done) =>
    @chatView.print("<h2>Turn #{turn}</h2>")
    @model.set('turn', turn)
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

addPokemonImage = ($div, url, options = {}) ->
  scale = options.scale || 1
  image = new Image()
  $image = $(image)
  $image.load ->
    {width, height} = image
    if scale != 1
      width  *= scale
      height *= scale
      $image.width(width)
      $image.height(height)
    top  = ($div.height() - height) >> 1
    left = ($div.width() - width) >> 1
    $image.css(position: 'absolute', top: top, left: left)
    options.callback?($image, left, top)  # $image, x, y
  image.src = url
  $image.appendTo($div)
