class @BattleView extends Backbone.View
  template: JST['battle_actions']

  events:
    'click .move': 'makeMove'
    'click .switch': 'switchPokemon'

  initialize: =>
    @selected = null

  render: =>
    @$el.html @template(team: @model.you)
    this

  makeMove: (e) =>
    moveName = $(e.target).text()
    console.log "Making move #{moveName}"
    @model.makeMove(moveName)

  switchPokemon: (e) =>
    toPokemon = $(e.target).text()
    console.log "Switching to #{toPokemon}"
    @model.makeSwitch(toPokemon)
