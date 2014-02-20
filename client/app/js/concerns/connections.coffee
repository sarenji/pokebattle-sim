$body = $("body")
reconnectId = null
shouldReconnect = true

PokeBattle.cancelReconnection = ->
  clearTimeout(reconnectId)
  shouldReconnect = false

PokeBattle.socket.addEvents
  'close': (socket) ->
    return  if !shouldReconnect
    $popup = $('<div class="reconnect"/>')
      .addClass('popup-absolute')
      .hide()
    $div = $('<span/>')
      .addClass('alert')
      .html("<strong>You lost your connection to PokeBattle!</strong>
        <span class='reconnect-text'>
          Reconnecting in <span class='reconnect-timer'></span>...
          <span class='reconnect-link fake_link'>Reconnect now</span>
        </span>")
      .appendTo($popup)
    $popup.appendTo($body).fadeIn(250)
    reconnectTimer($popup)

reconnectTimer = ($popup) ->
  if !shouldReconnect
    $popup.remove()
    clearTimeout(reconnectId)
    return
  seconds = $body.data('seconds') ? 1
  if seconds == 0
    $popup.find('.reconnect-text').text("Reconnecting...")
    reconnect()
  else
    time  = "#{Math.floor(seconds / 60)}:"
    time += "00#{seconds % 60}".substr(-2)
    $popup.find('.reconnect-timer').text(time)
    $body.data('seconds', seconds - 1)
    reconnectId = setTimeout(reconnectTimer.bind(this, $popup), 1000)

reconnect = ->
  clearTimeout(reconnectId)
  return  if !PokeBattle.socket.closed
  PokeBattle.socket.reconnect(new SockJS('/socket'))
  PokeBattle.socket.connectionAttempts += 1
  $body.data('seconds', Math.pow(2, PokeBattle.socket.connectionAttempts))
  $popups = $(".reconnect")
  $popups.fadeOut(250, -> $popups.remove())

$(document).on('click', '.reconnect-link', reconnect)
