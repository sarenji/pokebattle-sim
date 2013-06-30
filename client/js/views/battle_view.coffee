class @BattleView extends Backbone.View
  template: JST['battle_actions']

  events:
    'click .move': 'makeMove'
    'click .switch': 'switchPokemon'

  initialize: =>
    @selected = null

  render: (validActions = {}) =>
    locals =
      team         : @model.you
      opponent     : @model.opponents[0]
      validActions : validActions
    @$el.html @template(locals)
    this

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
    @render(validActions)

  disableButtons: =>
    @render()

  makeMove: (e) =>
    moveName = @getText(e.target)
    if @isDisabled()
      console.log "Cannot use #{moveName}."
      return
    console.log "Making move #{moveName}"
    @model.makeMove(moveName)
    @disableButtons()

  switchPokemon: (e) =>
    toPokemon = @getText(e.target)
    if @isDisabled()
      console.log "Cannot switch to #{toPokemon}."
      return
    console.log "Switching to #{toPokemon}"
    @model.makeSwitch(toPokemon)
    @disableButtons()
