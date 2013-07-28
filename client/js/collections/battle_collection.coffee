Protocol =
  CHANGE_HP      : 1
  SWITCH         : 2
  CHANGE_PP      : 3
  REQUEST_ACTION : 4

class @BattleCollection extends Backbone.Collection
  model: Battle

  initialize: (models, options) =>
    {@socket} = options

    @socket.addEvents
      'start battle': @startBattle
      'update battle': @updateBattle
      'battle switch': @battleSwitch

  startBattle: (socket, id, numActive, index, teams) =>
    console.log "BATTLE STARTED."
    $battle = $('.battle')
    battle = new Battle({id, numActive, socket, index, teams})
    battle.view = new BattleView(el: $battle, model: battle)
    @add(battle)

  updateBattle: (socket, battleId, actions) =>
    view = @get(battleId).view
    for action in actions
      [ type, player, rest... ] = action
      protocol = (key  for key, value of Protocol when value == type)[0]
      console.log "Received protocol: #{protocol}"
      switch type
        when Protocol.CHANGE_HP
          [slot, newHP] = rest
          view.model.getPokemon(player, slot).hp = newHP
          # TODO: Have this be called automatically.
          view.changeHP(player, slot)
        when Protocol.SWITCH
          team = view.model.getTeam(player)
          [toSlot, fromSlot] = rest
          [team[toSlot], team[fromSlot]] = [team[fromSlot], team[toSlot]]
          # TODO: Again, automatic.
          view.renderBattle()
        when Protocol.CHANGE_PP
          [slot, moveIndex, newPP] = rest
          pokemon = view.model.getPokemon(player, slot)
          pokemon.pp[moveIndex] = newPP
        when Protocol.REQUEST_ACTION
          [validActions] = rest
          console.log "ACTION REQUESTED:"
          console.log validActions
          view.enableButtons(validActions)


  battleSwitch: (socket, battleId, playerIndex, fromSlot, toSlot) =>
    view = @get(battleId).view
    team = view.model.getTeam(playerIndex)
    [team[toSlot], team[fromSlot]] = [team[fromSlot], team[toSlot]]
    view.renderAll()
