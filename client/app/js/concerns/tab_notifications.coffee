DEFAULT_INTERVAL = 1000
original  = document.title
timeoutId = undefined

$.flashTitle = (newMsg, interval) ->
  if newMsg == false
    # stop flashing and reset title
    clearTimeout(timeoutId)
    document.title = original
  else
    # loop flashing
    interval = interval || DEFAULT_INTERVAL
    timeoutId = setTimeout( ->
      clearTimeout(timeoutId)
      document.title = if (document.title == original) then newMsg else original
      timeoutId = setTimeout(arguments.callee, interval)
    , interval)

# TODO: Count the notifications by unique type/identifier combos
PokeBattle.notifyTab = (type, identifier) =>
  return  if document.hasFocus()
  $.flashTitle "You have new notification(s)"

$(window).focus ->
  $.flashTitle(false)