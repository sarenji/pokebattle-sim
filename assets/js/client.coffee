#= require templates/index
#= require_tree templates
#= require_tree models
#= require_tree collections
#= require_tree views

socket = io.connect(window.location.origin)
socket.on 'connect', ->
  socket.emit 'adduser', prompt("What's your name?"), ->
    socket.on 'updatechat', (username, data) ->
      $("#messages").append("<p>#{username}: #{data}</p>")

    # Attach events to DOM
    $(document).on 'keyup', '#chat', (e) ->
      if e.which == 13
        socket.emit 'sendchat', $(this).val()
        $(this).val('')

    socket.on 'start battle', startBattle

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
  view.render()
  socket.on 'switch pokemon', (fromIndex, toIndex) ->
    battle.switch(fromIndex, toIndex)
    view.render()
