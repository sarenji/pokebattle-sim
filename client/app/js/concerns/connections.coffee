$body = $("body")
$popup = $('#popup')

PokeBattle.primus.on 'connection', ->
  $popup.hide()

PokeBattle.primus.on 'reconnecting', (opts) ->
  seconds = Math.floor(opts.timeout / 1000)
  if $popup.length == 0
    $popup = $('<div id="popup" class="reconnect popup-absolute"/>').hide()
    $div = $('<span/>')
      .addClass('alert')
      .html("<strong>You lost your connection to PokeBattle!</strong>
        <span class='reconnect-text'>
          Reconnecting in
          <span class='reconnect-timer'>#{seconds}</span>
          seconds...
        </span>")
      .appendTo($popup)
    $popup.appendTo($body)
  $popup.fadeIn(250)
  $body.data('seconds', seconds)
  reconnectTimer($popup)

reconnectTimer = ($popup) ->
  seconds = $body.data('seconds') ? 1
  if seconds == 0
    $popup.find('.reconnect-text').text("Reconnecting...")
    PokeBattle.primus = Primus.connect()
  else
    time  = "#{Math.floor(seconds / 60)}:"
    time += "00#{seconds % 60}".substr(-2)
    $popup.find('.reconnect-timer').text(time)
    $body.data('seconds', seconds - 1)
    setTimeout(reconnectTimer.bind(this, $popup), 1000)
