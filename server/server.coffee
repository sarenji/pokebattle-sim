{createHmac} = require 'crypto'
{_} = require 'underscore'

{User} = require('./user')
{BattleQueue} = require './queue'
{UserStore} = require './user_store'
async = require('async')
gen = require './generations'
auth = require('./auth')
learnsets = require '../shared/learnsets'
{Conditions, SelectableConditions, Formats, DEFAULT_FORMAT} = require '../shared/conditions'
pbv = require '../shared/pokebattle_values'
config = require './config'
errors = require '../shared/errors'
redis = require('./redis')
alts = require './alts'

FIND_BATTLE_CONDITIONS = [
  Conditions.TEAM_PREVIEW
  Conditions.RATED_BATTLE
  Conditions.TIMED_BATTLE
  Conditions.SLEEP_CLAUSE
  Conditions.EVASION_CLAUSE
  Conditions.SPECIES_CLAUSE
  Conditions.PRANKSTER_SWAGGER_CLAUSE
  Conditions.OHKO_CLAUSE
  Conditions.UNRELEASED_BAN
]

MAX_NICKNAME_LENGTH = 15

class @BattleServer
  constructor: ->
    @queues = {}
    for format of Formats
      @queues[format] = new BattleQueue()
    @battles = {}

    # A hash mapping users to battles.
    @userBattles = {}

    # same as user battles, but indexed by name and does not include alts
    @visibleUserBattles = {}

    # A hash mapping user ids to challenges
    # challenges[challengeeId][challengerId] = {generation: 'xy', team: []}
    @challenges = {}

    # A hash mapping ids to users
    @users = new UserStore()

    @rooms = []

    # Battles can start.
    @unlockdown()

  # Creates a new user or finds an existing one, and adds a spark to it
  findOrCreateUser: (json, spark) ->
    user = @users.get(json.name)
    user = @users.add(json, spark)
    user

  join: (spark) ->
    @showTopic(spark)
    for battleId of @userBattles[spark.user.name]
      battle = @battles[battleId]
      battle.addSpectator(spark)
      battle.sendRequestTo(spark.user.name)
      battle.sendUpdates()
    return spark

  leave: (spark) ->
    for room in @rooms
      room.remove(spark)
    @users.remove(spark)
    return  if spark.user.hasSparks()
    @stopChallenges(spark.user)

  showTopic: (player) ->
    redis.hget "topic", "main", (err, topic) ->
      player.send('topic', topic)  if topic

  registerChallenge: (player, challengeeId, format, team, conditions, altName) ->
    if @isLockedDown()
      errorMessage = "The server is locked. No new battles can start at this time."
      player.error(errors.PRIVATE_MESSAGE, challengeeId, errorMessage)
      return false
    else if !@users.contains(challengeeId)
      errorMessage = "This user is offline."
      player.error(errors.PRIVATE_MESSAGE, challengeeId, errorMessage)
      return false
    else if player.name == challengeeId
      errorMessage = "You cannot challenge yourself."
      player.error(errors.PRIVATE_MESSAGE, challengeeId, errorMessage)
      return false
    else if @challenges[player.name]?[challengeeId] ||
            @challenges[challengeeId]?[player.name]
      errorMessage = "A challenge already exists between you two."
      player.error(errors.PRIVATE_MESSAGE, challengeeId, errorMessage)
      return false

    # Do not allow rated battles or other unallowed conditions.
    if _.difference(conditions, SelectableConditions).length > 0
      player.error(errors.FIND_BATTLE, 'This battle cannot have certain conditions.')
      return false

    err = @validateTeam(team, format, conditions)
    if err.length > 0
      # TODO: Use a modal error instead
      player.error(errors.FIND_BATTLE, err)
      return false

    @challenges[player.name] ?= {}
    @challenges[player.name][challengeeId] = {format, team, conditions, challengerName: player.name, altName}
    challengee = @users.get(challengeeId)
    challengee.send("challenge", player.name, format, conditions)
    return true

  acceptChallenge: (player, challengerId, team, altName) ->
    if !@challenges[challengerId]?[player.name]?
      errorMessage = "The challenge no longer exists."
      player.error(errors.PRIVATE_MESSAGE, challengerId, errorMessage)
      return null

    challenge = @challenges[challengerId][player.name]
    err = @validateTeam(team, challenge.format, challenge.conditions)
    if err.length > 0
      # TODO: Use a modal error instead
      player.error(errors.FIND_BATTLE, err)
      return null

    teams = [
      {
        id: challengerId,
        name: challenge.altName || challenge.challengerName,
        team: challenge.team,
        ratingKey: alts.uniqueId(challengerId, challenge.altName)
      }
      {
        id: player.name,
        name: altName || player.name,
        team: team,
        ratingKey: alts.uniqueId(player.name, altName)
      }
    ]

    id = @createBattle(challenge.format, teams, challenge.conditions)
    challenger = @users.get(challengerId)
    challenger.send("challengeSuccess", player.name)
    player.send("challengeSuccess", challengerId)
    delete @challenges[challengerId][player.name]
    return id

  rejectChallenge: (player, challengerId) ->
    if !@challenges[challengerId]?[player.name]?
      errorMessage = "The challenge no longer exists."
      player.error(errors.PRIVATE_MESSAGE, challengerId, errorMessage)
      return false
    delete @challenges[challengerId][player.name]
    player.send("rejectChallenge", challengerId)
    challenger = @users.get(challengerId)
    challenger.send("rejectChallenge", player.name)

  cancelChallenge: (player, challengeeId) ->
    if !@challenges[player.name]?[challengeeId]?
      errorMessage = "The challenge no longer exists."
      player.error(errors.PRIVATE_MESSAGE, challengeeId, errorMessage)
      return false
    delete @challenges[player.name][challengeeId]
    player.send("cancelChallenge", challengeeId)
    challengee = @users.get(challengeeId)
    challengee.send("cancelChallenge", player.name)

  stopChallenges: (player) ->
    playerId = player.name
    for challengeeId of @challenges[playerId]
      @cancelChallenge(player, challengeeId)
    delete @challenges[playerId]
    for challengerId of @challenges
      if @challenges[challengerId][playerId]
        @rejectChallenge(player, challengerId)

  # Adds the player to the queue. Note that there is no validation on whether altName
  # is correct, so make
  queuePlayer: (playerId, team, format = DEFAULT_FORMAT, altName) ->
    if @isLockedDown()
      err = ["The server is restarting after all battles complete. No new battles can start at this time."]
    else if format != DEFAULT_FORMAT
      # TODO: Implement ratings for other formats
      err = ["The server doesn't support this ladder at this time. Please ask for challenges instead."]
    else
      err = @validateTeam(team, format, FIND_BATTLE_CONDITIONS)
      if err.length == 0
        name = @users.get(playerId).name
        ratingKey = alts.uniqueId(playerId, altName)
        @queues[format].add(playerId, altName || name, team, ratingKey)
      return err

  queuedPlayers: (format = DEFAULT_FORMAT) ->
    @queues[format].queuedPlayers()

  removePlayer: (playerId, format = DEFAULT_FORMAT) ->
    return false  if format not of @queues
    @queues[format].remove(playerId)
    return true

  beginBattles: (next) ->
    array = for format in Object.keys(Formats)
      do (format) => (callback) =>
        @queues[format].pairPlayers (err, pairs) =>
          if err then return callback(err)

          # Create a battle for each pair
          battleIds = []
          for pair in pairs
            id = @createBattle(format, pair, FIND_BATTLE_CONDITIONS)
            battleIds.push(id)
          callback(null, battleIds)
    async.parallel array, (err, battleIds) ->
      return next(err)  if err
      next(null, _.flatten(battleIds))
    return true

  # Creates a battle and returns its battleId
  createBattle: (rawFormat = DEFAULT_FORMAT, pair = [], conditions = []) ->
    format = Formats[rawFormat]
    generation = format.generation
    conditions = conditions.concat(format.conditions)
    {Battle} = require("../server/#{generation}/battle")
    {BattleController} = require("../server/#{generation}/battle_controller")
    playerIds = pair.map((user) -> user.name)
    battleId = @generateBattleId(playerIds)
    battle = new Battle(battleId, pair, format: rawFormat, conditions: _.clone(conditions))
    @battles[battleId] = new BattleController(battle)
    for player in pair
      # Add user to spectators
      # TODO: player.id should be using player.name, but alts present a problem.
      user = @users.get(player.id)
      battle.addSpectator(spark)  for spark in user.sparks

      # Add/remove player ids to/from user battles
      @userBattles[player.id] ?= {}
      @userBattles[player.id][battleId] = true

      # Add the player to the list if its not an alt
      if player.id == player.ratingKey  # hacky - but no alternative right now
        @visibleUserBattles[player.id] ?= {}
        @visibleUserBattles[player.id][battleId] = true

      battle.once 'end', @removeUserBattle.bind(this, player.id, player.name, battleId)
      battle.once 'expire', @removeBattle.bind(this, battleId)

    @battles[battleId].beginBattle()
    battleId

  # Generate a random ID for a new battle.
  generateBattleId: (players) ->
    hmac = createHmac('sha1', config.SECRET_KEY)
    hmac.update((new Date).toISOString())
    for id in players
      hmac.update(id)
    hmac.digest('hex')

  # Returns the battle with battleId.
  findBattle: (battleId) ->
    @battles[battleId]

  getUserBattles: (userId) ->
    (id  for id, value of @userBattles[userId])

  # Returns all non-alt battles the user is playing in
  getVisibleUserBattles: (username) ->
    (id  for id, value of @visibleUserBattles[username])

  getOngoingBattles: ->
    # TODO: This is very inefficient. Improve this.
    _.chain(@battles).values().reject((b) -> b.battle.isOver()).value()

  removeUserBattle: (userId, username, battleId) ->
    delete @userBattles[userId][battleId]
    delete @visibleUserBattles[username]?[battleId]

  removeBattle: (battleId) ->
    delete @battles[battleId]

  # A length of -1 denotes a permanent ban.
  ban: (username, reason, length = -1) ->
    auth.ban(username, reason, length)
    if user = @users.get(username)
      user.error(errors.BANNED, reason, length)
      user.close()

  unban: (username, next) ->
    auth.unban(username, next)

  mute: (username, reason, length) ->
    auth.mute(username, reason, length)

  unmute: (username) ->
    auth.unmute(username)

  announce: (message) ->
    for room in @rooms
      room.announce("warning", message)
    for battleId, battle of @battles
      battle.rawMessage("""<div class="alert alert-warning">#{message}</div>""")

  userMessage: (room, user, message) ->
    auth.getMuteTTL user.name, (err, ttl) ->
      if ttl == -2
        room.userMessage(user, message)
      else
        user.announce('warning', "You are muted for another #{ttl} seconds!")

  setAuthority: (user, newAuthority) ->
    user = @users.get(user)  if user not instanceof User
    user.authority = newAuthority  if user

  lockdown: ->
    @canBattlesStart = false
    for user in @users.getUsers()
      @stopChallenges(user)
    @announce("<strong>The server is restarting!</strong> We're waiting for all battles to finish to push some updates. No new battles may start at this time.")

  unlockdown: ->
    @canBattlesStart = true
    @announce("<strong>Battles have been unlocked!</strong> You may battle again.")

  isLockedDown: ->
    !@canBattlesStart

  # Returns an empty array if the given team is valid, an array of errors
  # otherwise.
  validateTeam: (team, format = DEFAULT_FORMAT, conditions = []) ->
    return [ "Invalid format: #{format}." ]  if format not of Formats
    format = Formats[format]
    return [ "Invalid team format." ]  if team not instanceof Array
    return [ "Team must have 1 to 6 Pokemon." ]  unless 1 <= team.length <= 6
    conditions = conditions.concat(format.conditions)
    genData = gen.GenerationJSON[format.generation.toUpperCase()]

    err = require('./conditions').validateTeam(conditions, team, genData)
    return err  if err.length > 0

    err = team.map (pokemon, i) =>
      @validatePokemon(conditions, pokemon, i + 1, format.generation)
    return _.flatten(err)

  # Returns an empty array if the given Pokemon is valid, an array of errors
  # otherwise.
  validatePokemon: (conditions, pokemon, slot, generation = gen.DEFAULT_GENERATION) ->
    genData = gen.GenerationJSON[generation.toUpperCase()]
    {SpeciesData, FormeData, MoveData} = genData
    err = []
    prefix = "Slot ##{slot}"

    if !pokemon.species
      err.push("#{prefix}: No species given.")
      return err
    species = SpeciesData[pokemon.species]
    if !species
      err.push("#{prefix}: Invalid species: #{pokemon.species}.")
      return err

    prefix += " (#{pokemon.species})"
    @normalizePokemon(pokemon, generation)
    forme = FormeData[pokemon.species][pokemon.forme]
    if !forme
      err.push("#{prefix}: Invalid forme: #{pokemon.forme}.")
      return err

    if forme.isBattleOnly
      err.push("#{prefix}: #{pokemon.forme} forme is battle-only.")
      return err

    unless 0 < pokemon.name.length <= MAX_NICKNAME_LENGTH
      err.push("#{prefix}: Nickname cannot be blank or be
                #{MAX_NICKNAME_LENGTH} characters or higher.")
      return err

    if pokemon.name != pokemon.species && pokemon.name of SpeciesData
      err.push("#{prefix}: Nickname cannot be another Pokemon's name.")
      return err

    if /[\u0300-\u036F\u20D0-\u20FF\uFE20-\uFE2F]/.test(pokemon.name)
      err.push("#{prefix}: Nickname cannot contain some special characters.")
      return err

    if isNaN(pokemon.level)
      err.push("#{prefix}: Invalid level: #{pokemon.level}.")
    # TODO: 100 is a magic constant
    else if !(1 <= pokemon.level <= 100)
      err.push("#{prefix}: Level must be between 1 and 100.")

    if pokemon.gender not in [ "M", "F", "Genderless" ]
      err.push("#{prefix}: Invalid gender: #{pokemon.gender}.")
    if species.genderRatio == -1 && pokemon.gender != "Genderless"
      err.push("#{prefix}: Must be genderless.")
    if species.genderRatio == 0 && pokemon.gender != "M"
      err.push("#{prefix}: Must be male.")
    if species.genderRatio == 8 && pokemon.gender != "F"
      err.push("#{prefix}: Must be female.")
    if (typeof pokemon.evs != "object")
      err.push("#{prefix}: Invalid evs.")
    if (typeof pokemon.ivs != "object")
      err.push("#{prefix}: Invalid ivs.")
    if !_.chain(pokemon.evs).values().all((ev) -> 0 <= ev <= 255).value()
      err.push("#{prefix}: EVs must be between 0 and 255.")
    if !_.chain(pokemon.ivs).values().all((iv) -> 0 <= iv <= 31).value()
      err.push("#{prefix}: IVs must be between 0 and 31.")
    if _.values(pokemon.evs).reduce(((x, y) -> x + y), 0) > 510
      err.push("#{prefix}: EV total must be less than 510.")
    if pokemon.ability not in forme["abilities"] &&
       pokemon.ability != forme["hiddenAbility"]
      err.push("#{prefix}: Invalid ability.")
    if pokemon.moves not instanceof Array
      err.push("#{prefix}: Invalid moves.")
    # TODO: 4 is a magic constant
    else if !(1 <= pokemon.moves.length <= 4)
      err.push("#{prefix}: Must have 1 to 4 moves.")
    else if !_(pokemon.moves).all((name) -> MoveData[name]?)
      invalidMove = _(pokemon.moves).find((name) -> !MoveData[name]?)
      err.push("#{prefix}: Invalid move name: #{invalidMove}")
    else if !learnsets.checkMoveset(gen.GenerationJSON, pokemon,
                        gen.GENERATION_TO_INT[generation], pokemon.moves)
      err.push("#{prefix}: Invalid moveset.")
    err.push require('./conditions').validatePokemon(conditions, pokemon, genData, prefix)...
    return err

  # Normalizes a Pokemon by setting default values where applicable.
  # Assumes that the Pokemon is a real Pokemon (i.e. its species/forme is valid)
  normalizePokemon: (pokemon, generation = gen.DEFAULT_GENERATION) ->
    {SpeciesData, FormeData} = gen.GenerationJSON[generation.toUpperCase()]
    pokemon.forme   ?= "default"
    pokemon.name    ?= pokemon.species
    pokemon.ability ?= FormeData[pokemon.species][pokemon.forme]?["abilities"][0]
    if !pokemon.gender?
      {genderRatio} = SpeciesData[pokemon.species]
      if genderRatio == -1 then pokemon.gender = "Genderless"
      else if Math.random() < (genderRatio / 8) then pokemon.gender = "F"
      else pokemon.gender = "M"
    pokemon.evs     ?= {}
    pokemon.ivs     ?= {}
    pokemon.level   ?= 100
    pokemon.level    = Math.floor(pokemon.level)
    return pokemon
