class PokeBattleRouter extends Backbone.Router
  routes:
    "" : "main"
    "battles/:id" : "spectateBattle"

  main: =>
    $navigation = $('#navigation')
    $navigation.find('.nav_item').first().click()

  spectateBattle: (id) =>
    if PokeBattle.battles.get(id)
      PokeBattle.navigation.changeWindowToBattle(id)
    else
      PokeBattle.primus.send('spectateBattle', id)

PokeBattle.router = new PokeBattleRouter()

PokeBattle.primus.once "loginSuccess", ->
  return  if Backbone.History.started
  PokeBattle.events.trigger("ready")
  routed = Backbone.history.start(pushState: true)
