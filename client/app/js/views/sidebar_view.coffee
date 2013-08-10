class @SidebarView extends Backbone.View
  template: JST['navigation']

  initialize: (attributes) =>
    @listenTo(BattleTower.battles, 'add remove reset', @render)
    @render()

  render: =>
    @$el.html @template(battles: BattleTower.battles)
