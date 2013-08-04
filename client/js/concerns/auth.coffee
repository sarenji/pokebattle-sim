$(window).load ->
  $(document).on('click', '.login',  -> navigator.id.request())
  $(document).on('click', '.logout', -> navigator.id.logout())

  navigator.id.watch
    onlogin: (assertion) ->
      BattleTower.socket.send('assert login', assertion)
    onlogout: ->
      BattleTower.socket.send('logout')

  BattleTower.socket.addEvents
    'login success': (socket, user) ->
      # TODO: Hide login button, ask username, etc.
      BattleTower.username = user.id

    'login fail': (socket) ->
      navigator.id.logout()
