#= require templates/index
#= require_tree templates
#= require_tree models
#= require_tree collections
#= require_tree views

# A wrapper around the sockjs socket to support a higher level of abstraction
# Todo: Move this somewhere else
class @Socket
  constructor: (socket) ->
    @socket = socket
    @callbacks = {}

    handleEvent = (type, data) =>
      console.log "Received event #{type}"

      data ?= []
      for callback in (@callbacks[type] || [])
        callback.apply(this, [this, data...])

    @socket.onopen = =>
      handleEvent('connect')

    @socket.onmessage = (data) =>
      # todo: error handling. If there's a syntax error here, its because of Json.parse
      data = JSON.parse(data.data)
      handleEvent(data.messageType, data.data)

    @socket.onclose = => # nothing yet

  on: (type, callback) ->
    @callbacks[type] ?= []
    @callbacks[type].push(callback)

  addEvents: (events) ->
    @on(type, callback) for type, callback of events

  send: (type, data...) ->
    @socket.send(JSON.stringify(messageType: type, data: data))

@BattleTower = BattleTower = {}
BattleTower.battles = {}
socket = null
chatView = null

$ ->
  #$builder = $('.builder')
  #pokemon = new Team(({name: "Bulbasaur"}  for x in [0...6]))
  #builderView = new TeamBuilderView(el: $builder, collection: pokemon)
  #builderView.render()

  socket = new Socket(new SockJS('/socket'))
  socket.addEvents
    'connect': ->
      randomName = (name  for name of PokemonData)
      randomName = randomName[Math.floor(Math.random() * randomName.length)]
      randomName = randomName.split(/\s+/)[0]
      randomName += "Fan" + Math.floor(Math.random() * 10000)
      socket.send 'login', randomName

    'login result': (socket, id, username, userList) ->
      socket.id = id
      BattleTower.userList = new UserList(userList)
      chatView = new ChatView(
        el: $('.chat')
        collection: BattleTower.userList
        socket: socket
      )
      chatView.render()

    'updatechat': (socket, username, data) ->
      chatView.updateChat("<b>#{username}:</b> #{data}")

    'join chatroom': (socket, userHash) ->
      BattleTower.userList.add(userHash)
      chatView.updateChat("#{userHash.name} joined BattleTower!")

    'start battle': startBattle

    'update battle': updateBattle

    'battle switch': battleSwitch

    'request action': requestAction

    'error': (socket, message) ->
      alert(message)


startBattle = (socket, id, numActive, index, teams) ->
  console.log "BATTLE STARTED."
  $battle = $('.battle')
  battle = new Battle({id, numActive, socket, index, teams})
  view = new BattleView(el: $battle, model: battle)
  BattleTower.battles[id] = view

requestAction = (socket, battleId, validActions, team) ->
  view = BattleTower.battles[battleId]
  battle = view.model
  console.log "ACTION REQUESTED:"
  console.log validActions
  battle.teams[battle.index] = team
  view.enableButtons(validActions)

Protocol =
  CHANGE_HP: 1

updateBattle = (socket, battleId, actions) ->
  view = BattleTower.battles[battleId]
  for action in actions
    [ type, player, rest... ] = action
    switch type
      when Protocol.CHANGE_HP
        [slot, newHP] = rest
        view.model.teams[player].pokemon[slot].hp = newHP
        # TODO: Have this be called automatically.
        view.changeHP(player, slot)

battleSwitch = (socket, battleId, playerIndex, fromSlot, toSlot) ->
  view = BattleTower.battles[battleId]
  team = view.model.getTeam(playerIndex)
  [team[toSlot], team[fromSlot]] = [team[fromSlot], team[toSlot]]
  view.renderAll()
