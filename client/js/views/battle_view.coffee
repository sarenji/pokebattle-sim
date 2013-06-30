class @BattleView extends Backbone.View
  template: JST['battle_actions']

  events:
    'click .move': 'makeMove'
    'click .switch': 'switchPokemon'

  initialize: =>
    @selected = null
    @disabled = false

  render: =>
    locals =
      team:     @model.you
      opponent: @model.opponents[0]
      disabled: @disabled
    @$el.html @template(locals)
    this

  getText: (el) =>
    $el = $(el)
    $el = $el.closest('.button')  if !$el.hasClass('button')
    $el = $el.find(".main_text")  if !$el.hasClass('main_text')
    $el.text()

  enableButtons: =>
    @disabled = false
    @render()

  disableButtons: =>
    @disabled = true
    @render()

  makeMove: (e) =>
    moveName = @getText(e.target)
    if @disabled
      console.log "Cannot use #{moveName}."
      return
    console.log "Making move #{moveName}"
    @model.makeMove(moveName)
    @disableButtons()

  switchPokemon: (e) =>
    toPokemon = @getText(e.target)
    if @disabled
      console.log "Cannot switch to #{toPokemon}."
      return
    console.log "Switching to #{toPokemon}"
    @model.makeSwitch(toPokemon)
    @disableButtons()
