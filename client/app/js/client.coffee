return  if PokeBattle.autoConnect == false

PokeBattle.primus = Primus.connect()

PokeBattle.primus.on 'listChatroom', (id, users) ->
  if room = PokeBattle.rooms.get(id: id)
    room.get('users').reset(users)
  else
    room = PokeBattle.rooms.add(id: id, users: users)
    new ChatView(model: room, el: $('#chat-section .chat')).render()

PokeBattle.primus.on 'userMessage', (id, username, data) ->
  room = PokeBattle.rooms.get(id)
  room.userMessage(username, data)

PokeBattle.primus.on 'rawMessage', (id, message) ->
  room = PokeBattle.rooms.get(id)
  room.rawMessage(message)

PokeBattle.primus.on 'announce', (id, klass, message) ->
  room = PokeBattle.rooms.get(id)
  room.announce(klass, message)

PokeBattle.primus.on 'joinChatroom', (id, user) ->
  room = PokeBattle.rooms.get(id)
  room.get('users').add(user)

PokeBattle.primus.on 'leaveChatroom', (id, user) ->
  room = PokeBattle.rooms.get(id)
  room.get('users').remove(user)

PokeBattle.primus.on 'topic', (topic) ->
  # TODO: Hardcoded
  room = PokeBattle.rooms.get("Lobby")
  room.setTopic(topic)

PokeBattle.userList = new UserList()
PokeBattle.battles = new BattleCollection([])
PokeBattle.messages = new PrivateMessages([])
PokeBattle.rooms = new Rooms([])

$ ->
  PokeBattle.navigation = new SidebarView(el: $('#navigation'))
  PokeBattle.teambuilder = new TeambuilderView(el: $("#teambuilder-section"))
  PokeBattle.battleList = new BattleListView(el: $("#battle-list-section"))
  new PrivateMessagesView(el: $("#messages"), collection: PokeBattle.messages)
