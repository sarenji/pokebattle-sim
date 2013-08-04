{createHmac} = require 'crypto'
{_} = require 'underscore'

{BattleQueue} = require './queue'
{Battle} = require './battle'
{BattleController} = require './battle_controller'

class @BattleServer
  constructor: ->
    @queue = new BattleQueue()
    @battles = {}

  queuePlayer: (player, team) ->
    @queue.add(player, team)

  queuedPlayers: ->
    @queue.queuedPlayers()

  beginBattles: ->
    pairs = @queue.pairPlayers()
    battles = []

    # Create a battle for each pair
    for pair in pairs
      id = @createBattle(pair...)
      @beginBattle(id)
      battle = pair.map((o) -> o.player)
      battle.push(id)
      battles.push(battle)

    battles

  # Creates a battle and returns its battleId
  createBattle: (objects...) ->
    players = objects.map (object) -> object.player
    battleId = @generateBattleId(players)
    @battles[battleId] = new BattleController(new Battle(battleId, players: objects))
    battleId

  beginBattle: (battleId) ->
    @battles[battleId].beginBattle()

  # Generate a random ID for a new battle.
  generateBattleId: (players) ->
    # TODO load key from config or env
    hmac = createHmac('sha1', 'INSECURE KEY')
    hmac.update((new Date).toISOString())
    for player in players
      hmac.update(player.id)
    hmac.digest('hex')

  # Returns the battle with battleId.
  findBattle: (battleId) ->
    @battles[battleId]
