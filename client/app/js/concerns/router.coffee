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
      PokeBattle.primus.send('spectateBattle', id)

PokeBattle.primus.once "loginSuccess", ->
  return  if Backbone.History.started
  PokeBattle.router = new PokeBattleRouter()
  PokeBattle.events.trigger("ready")
  routed = Backbone.history.start(pushState: true)
  if !routed then PokeBattle.router.navigate("")
