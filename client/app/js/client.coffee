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
      callback.apply(this, [this, data...])

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
    PokeBattle.userList = new UserList()
    PokeBattle.chatView = new ChatView(
      el: $('.chat_window .chat')
      collection: PokeBattle.userList
    )
    PokeBattle.chatView.render()
    if !PokeBattle.ready  # Only trigger this event once.
      PokeBattle.ready = true
      PokeBattle.events.trigger("ready")
    PokeBattle.events.trigger("connect")

  'login success': (socket, id) ->
    PokeBattle.events.trigger('login success', id)

  'list chatroom': (socket, users) ->
    PokeBattle.userList.reset(users)

  'update chat': (socket, username, data) ->
    PokeBattle.chatView.userMessage(username, data)

  'update battle chat': (socket, battleId, username, data) ->
    chatView = PokeBattle.battles.get(battleId).view.chatView
    chatView.userMessage(username, data)

  'raw message': (socket, message) ->
    PokeBattle.chatView.updateChat(message)

  'join chatroom': (socket, username) ->
    PokeBattle.userList.add(id: username)

  'leave chatroom': (socket, username) ->
    PokeBattle.userList.remove(id: username)

$ ->
  PokeBattle.battles = new BattleCollection([])
  PokeBattle.navigation = new SidebarView(el: $('#navigation'))
  PokeBattle.teambuilder = new TeambuilderView(el: $("#teambuilder-section"), teams: [])
