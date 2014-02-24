class @BattleListView extends Backbone.View
  template: JST['battle_list']

  initialize: (attributes) =>
    @battles = []
    @render()

  refreshList: =>
    PokeBattle.socket.send("getBattleList")
    # wait for refresh complete. It will be fired by concerns/battle_list.coffee

  refreshListComplete: (battles) =>
    @battles = _(battles).sortBy((battle) => battle[3])
    @render()

  render: =>
    @$el.html @template(battles: @battles)
