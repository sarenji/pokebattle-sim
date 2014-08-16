PokeBattle.events.once "ready", ->
  $loading = $(".loading-container")
  $loading.fadeOut(-> $loading.remove())
