@BattleTower ?= {}

@BattleTower.initializeAuth ?= ->
  if BattleTower.local
    console.log "Mocking login..."
    BattleTower.socket.send('assert login', "mocked assertion")
    return

  $(document).on('click', '.login',  -> navigator.id.request())
  $(document).on('click', '.logout', -> navigator.id.logout())

  navigator.id.watch
    onlogin: (assertion) ->
      console.log "Attempting to login."
      BattleTower.socket.send('assert login', assertion)
    onlogout: ->
      console.log "Logging out."
      BattleTower.socket.send('logout')

$(window).load ->
  BattleTower.socket.addEvents
    'login success': (socket, user) ->
      $('.login').hide()
      $('.greetings').html("Greetings, <strong>#{user.id}</strong>!")
      # TODO: ask for username, don't randomly generate from server
      BattleTower.username = user.id

    'login fail': (socket, reason) ->
      console.log "Could not login!"
      console.log reason
      navigator.id.logout()
