class @BattleView extends Backbone.View
  battle_template: JST['battle']
  action_template: JST['battle_actions']

  events:
    'click .move': 'makeMove'
    'click .switch': 'switchPokemon'

  initialize: =>
    @selected = null
    @renderBattle()

  renderBattle: =>
    locals =
      yourTeam     : @model.getTeam()
      opponentTeam : @model.getOpponentTeam()
      numActive    : @model.numActive
      yourIndex    : @model.index
      window       : window
    @$('.battle_container').html @battle_template(locals)
    @addImages()
    this

  renderActions: (validActions = {}) =>
    locals =
      yourTeam     : @model.getTeam()
      validActions : validActions
      window       : window
    @$('.battle_actions').html @action_template(locals)

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
    $pokemon = @$(".pokemon#{player}-#{slot}")
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

  faint: (player, slot) =>
    $pokemon = @$(".pokemon#{player}-#{slot}")
    $image = $pokemon.find('.sprite img')
    $image.css(top: "100%", opacity: 0)

  getText: (el) =>
    $el = $(el)
    $el = $el.closest('.button')  if !$el.hasClass('button')
    $el = $el.find(".main_text")  if !$el.hasClass('main_text')
    $el.text()

  isDisabled: (el) =>
    $el = $(el)
    $el = $el.closest('.button')  if !$el.hasClass('button')
    $el.hasClass('disabled')

  enableButtons: (validActions) =>
    @renderActions(validActions)

  disableButtons: =>
    @renderActions()

  addLog: (message) =>
    @$(".battle_chat").append("<p>#{message}</p>")

  beginTurn: (turn) =>
    @$('.battle_chat').append("<h2>Turn #{turn}</h2>")

  makeMove: (e) =>
    moveName = @getText(e.target)
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
  image.src = url
