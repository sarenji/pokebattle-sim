#= require templates/index
#= require_tree templates
#= require_tree models
#= require_tree collections
#= require_tree views

@BattleTower = BattleTower = {}

socket = io.connect(window.location.origin)
socket.on 'connect', ->
  randomName = (name  for name of PokemonData)
  randomName = randomName[Math.floor(Math.random() * randomName.length)]
  randomName = randomName.split(/\s+/)[0]
  randomName += "Fan" + Math.floor(Math.random() * 10000)

  socket.emit 'login', randomName, (username, userList) ->
    BattleTower.userList = new UserList(userList)
    chatView = new ChatView(
      el: $('.chat')
      collection: BattleTower.userList
      socket: socket
    )
    chatView.render()

    socket.on 'updatechat', (username, data) ->
      chatView.updateChat("<b>#{username}:</b> #{data}")

    socket.on 'join chatroom', (userHash) ->
      BattleTower.userList.add(userHash)
      chatView.updateChat("#{userHash.name} joined BattleTower!")

    socket.on 'start battle', startBattle

    socket.on 'error', (message) ->
      alert(message)

$ ->
  return
  $builder = $('.builder')
  pokemon = new Team(({name: "Bulbasaur"}  for x in [0...6]))
  builderView = new TeamBuilderView(el: $builder, collection: pokemon)
  builderView.render()

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
