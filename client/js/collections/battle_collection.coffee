Protocol =
  CHANGE_HP: 1

class @BattleCollection extends Backbone.Collection
  model: Battle

  initialize: (models, options) =>
    {@socket} = options

    @socket.addEvents
      'start battle': @startBattle
      'update battle': @updateBattle
      'battle switch': @battleSwitch
      'request action': @requestAction

  startBattle: (socket, id, numActive, index, teams) =>
    console.log "BATTLE STARTED."
    $battle = $('.battle')
    battle = new Battle({id, numActive, socket, index, teams})
    battle.view = new BattleView(el: $battle, model: battle)
    @add(battle)

  requestAction: (socket, battleId, validActions, team) =>
    console.log "ACTION REQUESTED:"
    console.log validActions

    battle = @get(battleId)
    view = battle.view
    battle.teams[battle.index] = team
    view.enableButtons(validActions)

  updateBattle: (socket, battleId, actions) =>
    view = @get(battleId).view
    for action in actions
      [ type, player, rest... ] = action
      switch type
        when Protocol.CHANGE_HP
          [slot, newHP] = rest
          view.model.teams[player].pokemon[slot].hp = newHP
          # TODO: Have this be called automatically.
          view.changeHP(player, slot)

  battleSwitch: (socket, battleId, playerIndex, fromSlot, toSlot) =>
    view = @get(battleId).view
    team = view.model.getTeam(playerIndex)
    [team[toSlot], team[fromSlot]] = [team[fromSlot], team[toSlot]]
    view.renderAll()
