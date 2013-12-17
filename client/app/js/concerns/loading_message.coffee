PokeBattle.events.on "ready", ->
  $loading = $(".loading-container")
  $loading.fadeOut(-> $loading.remove())
