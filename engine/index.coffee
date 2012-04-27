class @Engine
  constructor: (options = {}) ->
    {@moves, @pokemon} = options
    @battles = {}

  # Creates a battle and returns its battleId
  createBattle: (players...) ->
    battleId = @generateBattleId()
    battleId = @generateBattleId()  while battleId of @battles
    @battles[battleId] = new Battle(engine: this, players: players)
    battleId

  # Generate a random ID for a new battle.
  generateBattleId: =>
    Math.floor(Math.random() * 0xFFFFFF).toString(16)

