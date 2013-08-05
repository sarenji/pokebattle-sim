Protocol =
  CHANGE_HP      : 1
  SWITCH         : 2
  CHANGE_PP      : 3
  REQUEST_ACTION : 4
  START_TURN     : 5
  RAW_MESSAGE    : 6
  FAINT          : 7

class @BattleCollection extends Backbone.Collection
  model: Battle

  initialize: (models, options) =>
    BattleTower.socket.addEvents
      'start battle': @startBattle
      'update battle': @updateBattle
      'spectate battle': @spectateBattle

  startBattle: (socket, id, numActive, index, teams) =>
    console.log "BATTLE STARTED."
    # TODO: Handle hiding better.
    $mainNav = $('.main_nav').addClass('hidden')
    $battle = $('.battle')
    battle = new Battle({id, numActive, socket, index, teams})
    battle.view = new BattleView(el: $battle, model: battle)
    @add(battle)

  updateBattle: (socket, battleId, actions) =>
    view = @get(battleId).view
    wasAtBottom = BattleTower.chatView.isAtBottom()
    for action in actions
      [ type, rest... ] = action
      protocol = (key  for key, value of Protocol when value == type)[0]
      console.log "Received protocol: #{protocol}"
      switch type
        when Protocol.CHANGE_HP
          [player, slot, newHP] = rest
          view.model.getPokemon(player, slot).hp = newHP
          # TODO: Have this be called automatically.
          view.changeHP(player, slot)
        when Protocol.SWITCH
          [player, toSlot, fromSlot] = rest
          team = view.model.getTeam(player).pokemon
          [team[toSlot], team[fromSlot]] = [team[fromSlot], team[toSlot]]
          # TODO: Again, automatic.
          view.renderBattle()
        when Protocol.CHANGE_PP
          [player, slot, moveIndex, newPP] = rest
          pokemon = view.model.getPokemon(player, slot)
          pokemon.pp[moveIndex] = newPP
        when Protocol.REQUEST_ACTION
          [validActions] = rest
          console.log "ACTION REQUESTED:"
          console.log validActions
          view.enableButtons(validActions)
        when Protocol.START_TURN
          [turn] = rest
          view.addLog("<h2>Turn #{turn}</h2>")
        when Protocol.RAW_MESSAGE
          [message] = rest
          view.addLog("#{message}<br>")
        when Protocol.FAINT
          [player, slot] = rest
          view.faint(player, slot)
    if wasAtBottom then BattleTower.chatView.scrollToBottom()

  spectateBattle: (socket, id, numActive, teams) =>
    console.log "SPECTATING BATTLE #{id}."
    # Pick a random index; it doesn't matter too much.
    index = Math.round(Math.random())
    # TODO: Handle hiding better.
    $mainNav = $('.main_nav').addClass('hidden')
    $battle = $('.battle')
    battle = new Battle({id, numActive, socket, index, teams})
    battle.view = new BattleView(el: $battle, model: battle)
    @add(battle)
