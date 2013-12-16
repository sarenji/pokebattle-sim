PokeBattle.events.on "connect", ->
  $loading = $(".loading-container")
  $loading.fadeOut(-> $loading.remove())
