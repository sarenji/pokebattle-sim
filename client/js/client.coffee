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
      callback.apply(this, data) for callback in (@callbacks[type] || [])

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

    'login result': (id, username, userList) ->
      @id = id
      BattleTower.userList = new UserList(userList)
      chatView = new ChatView(
        el: $('.chat')
        collection: BattleTower.userList
        socket: socket
      )
      chatView.render()

    'updatechat': (username, data) ->
      chatView.updateChat("<b>#{username}:</b> #{data}")

    'join chatroom': (userHash) ->
      BattleTower.userList.add(userHash)
      chatView.updateChat("#{userHash.name} joined BattleTower!")

    'start battle': startBattle

    'error': (message) ->
      alert(message)


startBattle = (battleId, yourTeam, opponentTeams) ->
  console.log "BATTLE STARTED."
  $battle = $('.battle')
  battle = new Battle(id: battleId, socket: socket, you: yourTeam, opponents: opponentTeams)
  view = new BattleView(el: $battle, model: battle)
  socket.on 'switch pokemon', (fromIndex, toIndex) ->
    battle.switch(fromIndex, toIndex)
    view.render()
  socket.on 'request action', (battleId, validActions) ->
    console.log "ACTION REQUESTED:"
    console.log validActions
    if battle.id == battleId
      view.enableButtons(validActions)
