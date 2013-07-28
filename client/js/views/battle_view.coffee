class @BattleView extends Backbone.View
  template: JST['battle_container']
  battle_template: JST['battle']
  action_template: JST['battle_actions']

  events:
    'click .move': 'makeMove'
    'click .switch': 'switchPokemon'

  initialize: =>
    @selected = null
    # @listenTo(@model, 'change:hp', @changeHP)
    @$el.html @template()
    @renderBattle()

  renderBattle: =>
    locals =
      team         : @model.getTeam()
      opponent     : @model.getOpponentTeam()
      numActive    : @model.numActive
      yourIndex    : @model.index
    @$el.find('.battle_container').html @battle_template(locals)
    @addImages()
    this

  renderActions: (validActions = {}) =>
    locals =
      team         : @model.getTeam()
      validActions : validActions
    @$el.find('.battle_actions').html @action_template(locals)

  addImages: =>
    @$el.find('.preload').each ->
      $this = $(this)
      front = $this.hasClass('front')
      name  = $this.data('name')
      {id}  = PokemonData[name]
      url   = imageUrl(id, front: front)
      scale = if front then 1 else 2
      addPokemonImage($this, url, scale: scale)

  changeHP: (player, slot) =>
    $meta = @$el.find(".hp#{player}-#{slot}")
    $hp = $meta.find('.hp')
    $allHP = $meta.find('.hp, .hp-red')
    pokemon = @model.getPokemon(player, slot)
    percent = Math.floor(pokemon.hp * 100 / pokemon.maxHP)
    if percent <= 25
      $hp.css(backgroundColor: "#f00")
    else if percent <= 50
      $hp.css(backgroundColor: "#ff0")
    else
      $hp.css(backgroundColor: "#0f0")
    $allHP.width(percent + "%")

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
