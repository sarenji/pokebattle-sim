PokeBattle.socket.addEvents
  'close': (socket) ->
    $popup = $('<div/>')
      .addClass('popup-absolute')
      .hide()
    $div = $('<span/>')
      .addClass('alert')
      .html("<strong>Warning!</strong> You lost your connection to PokeBattle.")
      .appendTo($popup)
    $popup.appendTo($("body")).fadeIn(250)
