{BattleQueue} = require './queue'
{Battle} = require './battle'

class @BattleServer
  constructor: ->
    @queue = new BattleQueue(this)
    @battles = {}

  queuePlayer: (player) =>
    @queue.add(player)

  queuedPlayers: =>
    @queue.queuedPlayers()

  beginBattles: =>
    pairs = @queue.pairPlayers()

    # Create a battle for each pair
    for pair in pairs
      id = @createBattle(pair...)

      # Tell each player to start a battle with an id `id`.
      for player in pair
        player.emit? 'start battle', id

  # Creates a battle and returns its battleId
  createBattle: (players...) =>
    battleId = @generateBattleId()
    battleId = @generateBattleId()  while battleId of @battles
    @battles[battleId] = new Battle(engine: this, players: players)
    battleId

  # Generate a random ID for a new battle.
  # TODO: Use node's built in crypto library to generate a HMAC
  generateBattleId: =>
    Math.floor(Math.random() * 0xFFFFFF).toString(16)

  # Returns the battle with battleId.
  findBattle: (battleId) =>
    @battles[battleId]
