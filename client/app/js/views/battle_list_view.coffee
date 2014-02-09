class @BattleListView extends Backbone.View
  template: JST['battle_list']

  initialize: (attributes) =>
    @battles = []
    @render()

  refreshList: =>
    PokeBattle.socket.send("get battle list")
    # wait for refresh complete. It will be fired by concerns/battle_list.coffee

  refreshListComplete: (battles) =>
    @battles = battles
    @render()

  render: =>
    @$el.html @template(battles: @battles)