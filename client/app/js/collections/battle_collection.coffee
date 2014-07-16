class @BattleCollection extends Backbone.Collection
  model: Battle

  isPlaying: ->
    @find((battle) -> battle.isPlaying())?

  playingBattles: ->
    @filter((battle) -> battle.isPlaying())
