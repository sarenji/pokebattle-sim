class @BattleListView extends Backbone.View
  template: JST['battle_list']

  initialize: (attributes) =>
    @battles = []
    @render()

  refreshList: =>
    PokeBattle.primus.send "getBattleList", (battles) =>
      @battles = _(battles).sortBy((battle) => battle[3])
      @render()

  render: =>
    @$el.html @template(battles: @battles)
