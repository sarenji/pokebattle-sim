{createHmac} = require 'crypto'
{_} = require 'underscore'
{BattleQueue} = require './queue'
{Battle} = require './battle'


class @BattleServer
  constructor: ->
    @queue = new BattleQueue()
    @battles = {}

  queuePlayer: (player, team) =>
    @queue.add(player, team)

  queuedPlayers: =>
    @queue.queuedPlayers()

  beginBattles: =>
    pairs = @queue.pairPlayers()

    # Create a battle for each pair
    for pair in pairs
      id = @createBattle(pair...)

      # Tell each player to start a battle with an id `id`.
      players = pair.map (object) -> object.player
      for player in players
        player.emit? 'start battle', id

  # Creates a battle and returns its battleId
  createBattle: (objects...) =>
    players = objects.map (object) -> object.player
    battleId = @generateBattleId(players)
    @battles[battleId] = new Battle(players: objects)
    battleId

  # Generate a random ID for a new battle.
  generateBattleId: (players) =>
    # TODO load key from config or env
    hmac = createHmac('sha1', 'INSECURE KEY')
    hmac.update((new Date).toISOString())
    for player in players
      hmac.update(player.clientId)
    hmac.digest('hex')

  # Returns the battle with battleId.
  findBattle: (battleId) =>
    @battles[battleId]
