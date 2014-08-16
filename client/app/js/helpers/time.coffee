# TODO: Move more timer functionality into here

# TODO: Encapsulate this better. Maybe put humanizeTime in a time object with more functions?
PokeBattle.humanizeTime = (unixTime) =>
  unixTime = 0  if !unixTime? || unixTime < 0
  seconds = Math.floor(unixTime / 1000) % 60
  minutes = Math.floor(unixTime / 1000 / 60)
  seconds = String(seconds)
  return minutes + ":" + "00".substr(seconds.length) + seconds

$ ->
  window.setInterval( ->
    $(".elapsed-time").each ->
      $el = $(this)
      elapsedTime = Date.now() - $el.data("time-start")
      $el.text(PokeBattle.humanizeTime(elapsedTime))
  , 500)
