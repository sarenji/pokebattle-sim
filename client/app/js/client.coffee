# A wrapper around the sockjs socket to support a higher level of abstraction
# Todo: Move this somewhere else
class @Socket
  constructor: (socket) ->
    @closed = true
    @callbacks = {}
    @reconnect(socket)
    @connectionAttempts = 0

  reconnect: (socket) =>
    return  if !@closed
    @closed = false
    @socket = socket
    @socket.onopen = =>
      @handleEvent('connect')
      @connectionAttempts = 0

    @socket.onmessage = (data) =>
      # todo: error handling. If there's a syntax error here, its because of Json.parse
      data = JSON.parse(data.data)
      @handleEvent(data.messageType, data.data)

    @socket.onclose = =>
      @handleEvent('close')
      @closed = true

  handleEvent: (type, data) =>
    console.log "Received event #{type}"

    data ?= []
    for callback in (@callbacks[type] || [])
      callback.apply(this, [this].concat(data))

    PokeBattle.events.trigger(type, data...)

  on: (type, callback) ->
    @callbacks[type] ?= []
    @callbacks[type].push(callback)

  addEvents: (events) ->
    @on(type, callback) for type, callback of events

  send: (type, data...) ->
    @socket.send(JSON.stringify(messageType: type, data: data))

PokeBattle.ready = false
PokeBattle.socket = new Socket(new SockJS('/socket'))
PokeBattle.socket.addEvents
  'connect': (socket) ->

  'list chatroom': (socket, users) ->
    PokeBattle.userList.reset(users)

  'update chat': (socket, username, data) ->
    PokeBattle.chatView.userMessage(username, data)

  'update battle chat': (socket, battleId, username, data) ->
    chatView = PokeBattle.battles.get(battleId).view.chatView
    chatView.userMessage(username, data)

  'raw battle message': (socket, battleId, message) ->
    chatView = PokeBattle.battles.get(battleId).view.chatView
    chatView.updateChat(message)

  'raw message': (socket, message) ->
    PokeBattle.chatView.updateChat(message)

  'join chatroom': (socket, userJSON) ->
    PokeBattle.userList.add(userJSON)

  'leave chatroom': (socket, userJSON) ->
    PokeBattle.userList.remove(userJSON)

  'topic': (socket, topic) ->
    PokeBattle.chatView.setTopic(topic)

PokeBattle.userList = new UserList()
PokeBattle.battles = new BattleCollection([])
PokeBattle.messages = new PrivateMessages([])

PokeBattle.events.once 'ready', ->
  PokeBattle.navigation = new SidebarView(el: $('#navigation'))
  PokeBattle.teambuilder = new TeambuilderView(el: $("#teambuilder-section"), teams: [])
  PokeBattle.battleList = new BattleListView(el: $("#battle-list-section"))
  PokeBattle.chatView = new ChatView(
    el: $('.chat_window .chat')
    collection: PokeBattle.userList
  ).render()
  new PrivateMessagesView(el: $("#messages"), collection: PokeBattle.messages)
