$body = $("body")
$popup = $('#popup')

PokeBattle.primus.on 'open', ->
  $popup.hide()
  PokeBattle.rooms.rawMessage("Connected to the server!", class: "yellow italic")

PokeBattle.primus.on 'reconnecting', ->
  PokeBattle.rooms.rawMessage("Lost connection to the server...", class: "red italic")

PokeBattle.primus.on 'end', ->
  PokeBattle.rooms.rawMessage("Connection terminated!", class: "red italic")

PokeBattle.primus.on 'reconnecting', (opts) ->
  seconds = Math.floor(opts.timeout / 1000)
  if $popup.length == 0
    $popup = $('<div id="popup" class="reconnect popup-absolute"/>').hide()
    $div = $('<span/>')
      .addClass('alert')
      .html("<strong>You lost your connection to PokeBattle!</strong>
        <span class='reconnect-text'></span>")
      .appendTo($popup)
    $popup.appendTo($body)
  $popup.find('.reconnect-text').html("""Reconnecting in
    <span class='reconnect-timer'>#{seconds}</span> seconds...""")
  $popup.fadeIn(250)
  $body.data('seconds', seconds)
  reconnectTimer($popup)

reconnectTimer = ($popup) ->
  seconds = $body.data('seconds') ? 1
  if seconds == 0
    $popup.find('.reconnect-text').text("Reconnecting...")
  else
    time  = "#{Math.floor(seconds / 60)}:"
    time += "00#{seconds % 60}".substr(-2)
    $popup.find('.reconnect-timer').text(time)
    $body.data('seconds', seconds - 1)
    setTimeout(reconnectTimer.bind(this, $popup), 1000)
