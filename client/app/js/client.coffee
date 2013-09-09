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

@PokeBattle ?= {}
PokeBattle.socket = null
PokeBattle.chatView = null
PokeBattle.battles = null

$ ->
  PokeBattle.socket = new Socket(new SockJS('/socket'))
  PokeBattle.socket.addEvents
    'connect': (socket) ->
      PokeBattle.userList = new UserList()
      PokeBattle.chatView = new ChatView(
        el: $('.chat_window .chat')
        collection: PokeBattle.userList
      )
      PokeBattle.chatView.render()
      PokeBattle.initializeAuth()

    'list chatroom': (socket, users) ->
      PokeBattle.userList.reset(users)

    'update chat': (socket, user, data) ->
      PokeBattle.chatView.userMessage(user.id, data)

    'update battle chat': (socket, battleId, user, data) ->
      chatView = PokeBattle.battles.get(battleId).view.chatView
      chatView.userMessage(user.id, data)

    'raw message': (socket, message) ->
      PokeBattle.chatView.updateChat(message)

    'join chatroom': (socket, user) ->
      PokeBattle.userList.add(user)

    'leave chatroom': (socket, user) ->
      PokeBattle.userList.remove(user)

    'error': (socket, message) ->
      alert(message)

  PokeBattle.battles = new BattleCollection([])
  $navigation = $('#navigation')
  PokeBattle.navigation = new SidebarView(el: $navigation)
  $navigation.find('.nav_item').first().click()
  PokeBattle.teambuilder = new TeambuilderView(el: $("#teambuilder-section"), collection: new Team())
