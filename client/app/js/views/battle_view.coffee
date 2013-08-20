class @BattleView extends Backbone.View
  battle_template: JST['battle']
  user_info_template: JST['battle_user_info']
  action_template: JST['battle_actions']

  events:
    'click .move': 'makeMove'
    'click .switch': 'switchPokemon'

  initialize: =>
    @selected = null
    @chatView = null
    @lastMove = null
    @spectators = new UserList([])
    @renderBattle()
    @renderChat()

  renderBattle: =>
    locals =
      yourTeam     : @model.getTeam()
      opponentTeam : @model.getOpponentTeam()
      numActive    : @model.numActive
      yourIndex    : @model.index
      window       : window
    @$('.battle_pane').html @battle_template(locals)
    @renderUserInfo()
    @addImages()
    this

  renderChat: =>
    @chatView = new ChatView(
      el: @$('.chat')
      collection: @spectators
      chatEvent: 'send battle chat'
      chatArgs: [ @model.id ]
    ).render()
    this

  renderActions: (validActions = {}) =>
    locals =
      yourTeam     : @model.getTeam()
      validActions : validActions
      window       : window
    @$('.battle_actions').html @action_template(locals)
    this

  renderUserInfo: =>
    locals =
      yourTeam     : @model.getTeam()
      opponentTeam : @model.getOpponentTeam()
      numActive    : @model.numActive
      yourIndex    : @model.index
      window       : window
    @$('.battle_user_info').html @user_info_template(locals)
    this

  addImages: =>
    @$('.preload').each ->
      $this = $(this)
      front = $this.closest('.pokemon').hasClass('top')
      name  = $this.data('name')
      {id}  = PokemonData[name]
      url   = imageUrl(id, front: front)
      scale = if front then 1 else 2
      addPokemonImage($this, url, scale: scale)

  changeHP: (player, slot) =>
    $pokemon = @$pokemon(player, slot)
    $info = $pokemon.find(".pokemon-info")
    $hp = $info.find('.hp')
    $allHP = $info.find('.hp, .hp-red')
    pokemon = @model.getPokemon(player, slot)
    percent = Math.floor(pokemon.hp * 100 / pokemon.maxHP)
    if percent <= 25
      $hp.css(backgroundColor: "#f00")
    else if percent <= 50
      $hp.css(backgroundColor: "#ff0")
    else
      $hp.css(backgroundColor: "#0f0")
    $allHP.width(percent + "%")

  logMove: (player, slot, moveName) =>
    {owner} = @model.getTeam(player)
    pokemon = @model.getPokemon(player, slot)
    @addLog("#{owner}'s #{pokemon.name} used <strong>#{moveName}</strong>!")
    @lastMove = moveName

  moveSuccess: (player, slot, targetSlot) =>
    switch @lastMove
      when 'Substitute'
        $pokemon = @$pokemon(player, slot)
        $sprite = $pokemon.find('.sprite')
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
              .y( yOffset).ease('ease-in-quad').duration('.2s').then()
              .y(-yOffset >> 3).ease('ease-out-quad').duration('.1s').then()
              .y( yOffset >> 3).ease('ease-in-quad').duration('.1s').then()
              .pop().pop().pop().end()
          , 0

  endEffect: (player, slot, effect) =>
    switch effect
      when 'SubstituteAttachment'
        $pokemon = @$pokemon(player, slot)
        $sprite = $pokemon.find('.sprite')
        $sprite.removeClass('fade')
        $substitute = $pokemon.find('.substitute')
        move($substitute).set('opacity', 0).set('top', '100%')
          .then(-> $substitute.remove()).end()

  announceWinner: (player) =>
    {owner} = @model.getTeam(player)
    @chatView.print("<h3>#{owner} won!</h3>")
    @model.set('finished', true)

  announceForfeit: (player) =>
    {owner} = @model.getTeam(player)
    @chatView.print("<h3>#{owner} has forfeited!</h3>")
    @model.set('finished', true)

  $pokemon: (player, slot) =>
    @$(".pokemon#{player}-#{slot}")

  isFront: (player) =>
    @model.index != player

  faint: (player, slot) =>
    $pokemon = @$pokemon(player, slot)
    $image = $pokemon.find('.sprite img')
    $image.css(top: "100%", opacity: 0)
    @renderUserInfo()

  getMoveName: (el) =>
    $el = $(el)
    $el = $el.closest('.button')  if !$el.hasClass('button')
    $el.data('move-id')

  isDisabled: (el) =>
    $el = $(el)
    $el = $el.closest('.button')  if !$el.hasClass('button')
    $el.hasClass('disabled')

  enableButtons: (validActions) =>
    @renderActions(validActions)

  disableButtons: =>
    @renderActions()

  addLog: (message) =>
    @chatView.print("<p>#{message}</p>")

  beginTurn: (turn) =>
    @chatView.print("<h2>Turn #{turn}</h2>")

  makeMove: (e) =>
    moveName = @getMoveName(e.target)
    if @isDisabled()
      console.log "Cannot use #{moveName}."
      return
    console.log "Making move #{moveName}"
    @model.makeMove(moveName)
    @disableButtons()

  switchPokemon: (e) =>
    toSlot = $(e.currentTarget).data('slot')
    if @isDisabled()
      console.log "Cannot switch to #{toSlot}."
      return
    console.log "Switching to #{toSlot}"
    toSlot = parseInt(toSlot, 10)
    @model.makeSwitch(toSlot)
    @disableButtons()

  notify: =>
    @model.set('notifications', @model.get('notifications') + 1)

imageUrl = (id, options = {}) ->
  kind = if options.front then 'i' else 'b'
  id   = "000#{id}".substr(-3)
  "http://sprites.pokecheck.org/#{kind}/#{id}.gif"

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
    $image.appendTo($div)
    options.callback?($image, left, top)  # $image, x, y
  image.src = url
