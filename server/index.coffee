{BattleQueue} = require './queue'

class @BattleServer
  constructor: ->
    @queue = new BattleQueue(this)
    @battles = []
