socket = io.connect('http://localhost')
socket.on 'connect', ->
  socket.emit 'adduser', prompt("What's your name?"), ->
    socket.on 'updatechat', (username, data) ->
      $("#messages").append("<p>#{username}: #{data}</p>")

    # Attach events to DOM
    $(document).on 'keyup', '#chat', (e) ->
      if e.which == 13
        socket.emit 'sendchat', $(this).val()
        $(this).val('')

    socket.on 'start battle', (battleId) ->
      $(document).on 'click', 'button', ->
        socket.emit 'send move', battleId, $(this).text()
