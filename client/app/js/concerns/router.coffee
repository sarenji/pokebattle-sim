class PokeBattleRouter extends Backbone.Router
  routes:
    "" : "main"
    "battles/:id" : "spectateBattle"

  main: =>
    $navigation = $('#navigation')
    $navigation.find('.nav_item').first().click()

  spectateBattle: (id) =>
    # Need to login first!!
    if PokeBattle.battles.get(id)
      PokeBattle.navigation.changeWindowToBattle(id)
    else
      PokeBattle.socket.send('spectate battle', id)

PokeBattle.events.once "login success", ->
  return  if Backbone.History.started
  PokeBattle.router = new PokeBattleRouter()
  routed = Backbone.history.start(pushState: true)
  if !routed then @PokeBattle.router.navigate("")
