PokeBattle.primus = Primus.connect()

PokeBattle.primus.on 'listChatroom', (users) ->
  PokeBattle.userList.reset(users)

PokeBattle.primus.on 'updateChat', (username, data) ->
  PokeBattle.chatView.userMessage(username, data)

PokeBattle.primus.on 'updateBattleChat', (battleId, username, data) ->
  PokeBattle.battles.get(battleId)?.view.chatView.userMessage(username, data)

PokeBattle.primus.on 'rawBattleMessage', (battleId, message) ->
  PokeBattle.battles.get(battleId)?.view.chatView.updateChat(message)

PokeBattle.primus.on 'rawMessage', (message) ->
  PokeBattle.chatView.updateChat(message)

PokeBattle.primus.on 'announce', (klass, message) ->
  PokeBattle.chatView.announce(klass, message)

PokeBattle.primus.on 'joinChatroom', (userJSON) ->
  PokeBattle.userList.add(userJSON)

PokeBattle.primus.on 'leaveChatroom', (userJSON) ->
  PokeBattle.userList.remove(userJSON)

PokeBattle.primus.on 'topic', (topic) ->
  PokeBattle.chatView.setTopic(topic)

PokeBattle.userList = new UserList()
PokeBattle.battles = new BattleCollection([])
PokeBattle.messages = new PrivateMessages([])

$ ->
  PokeBattle.navigation = new SidebarView(el: $('#navigation'))
  PokeBattle.teambuilder = new TeambuilderView(el: $("#teambuilder-section"))
  PokeBattle.battleList = new BattleListView(el: $("#battle-list-section"))
  PokeBattle.chatView = new ChatView(
    el: $('.chat_window .chat')
    collection: PokeBattle.userList
  ).render()
  new PrivateMessagesView(el: $("#messages"), collection: PokeBattle.messages)
