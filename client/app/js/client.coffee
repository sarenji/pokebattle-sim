return  if PokeBattle.autoConnect == false

PokeBattle.primus = Primus.connect()

PokeBattle.primus.on 'listChatroom', (id, users) ->
  room = PokeBattle.rooms.add(id: id, users: users)
  new ChatView(model: room, el: $('#main-section .chat')).render()
  # TODO: Create ChatView
  # Note: have to figure out how to create it for regular rooms and then battle rooms...

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

PokeBattle.primus.on 'topic', (id, topic) ->
  room = PokeBattle.rooms.get(id)
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
