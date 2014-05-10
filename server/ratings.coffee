redis = require './redis'
async = require 'async'
alts = require './alts'
@algorithm = require('./elo')
@DECAY_AMOUNT = 5

USERS_RATED_KEY = "users:rated"
USERS_ACTIVE_KEY = "users:active"
RATINGS_KEY = "ratings"
RATINGS_ATTRIBUTES = Object.keys(@algorithm.createPlayer())
RATINGS_SUBKEYS = {}
for attribute in RATINGS_ATTRIBUTES
  RATINGS_SUBKEYS[attribute] = [RATINGS_KEY, attribute].join(':')
RATINGS_MAXKEY = "ratings:max"
RATINGS_PER_PAGE = 15

ALGORITHM_OPTIONS =
  systemConstant: 0.2  # Glicko2 tau

@results =
  WIN  : 1
  DRAW : 0.5  # In earlier generations, it's possible to draw.
  LOSE : 0

@setActive = (idArray, next) ->
  idArray = [idArray]  if idArray not instanceof Array
  idArray = idArray.map((id) -> id.toLowerCase())
  redis.sadd(USERS_ACTIVE_KEY, idArray, next)

RATIOS_KEY = 'ratios'
RATIOS_ATTRIBUTES = Object.keys(@results).map((key) -> key.toLowerCase())
RATIOS_SUBKEYS = {}
for attribute in RATIOS_ATTRIBUTES
  RATIOS_SUBKEYS[attribute] = [RATIOS_KEY, attribute].join(':')

# Used internally by the ratings system to update
# the max rating of user when a rating changes
# Id can either be the actual id, or an alt id
updateMaxRating = (id, next) =>
  id = alts.getIdOwner(id).toLowerCase()
  alts.listUserAlts id, (err, altNames) =>
    return next(err)  if err
    
    # Retrieve a list of all rating Keys
    ids = (alts.uniqueId(id, name) for name in altNames)
    ids.push(id)

    @getRatings ids, (err, results) ->
      return next(err)  if err
      redis.zadd(RATINGS_MAXKEY, Math.max(results...), id)
      next(null)

# Update the max ratings for multiple players
updateMaxRatings = (ids, next) ->
  ops = ids.map (id) ->
    (callback) -> updateMaxRating(id, callback)
  async.parallel ops, next

@getPlayer = (id, next) ->
  id = id.toLowerCase()
  multi = redis.multi()
  for attribute in RATINGS_ATTRIBUTES
    multi = multi.zscore(RATINGS_SUBKEYS[attribute], id)
  multi.exec (err, results) ->
    return next(err)  if err
    object = {}
    for value, i in results
      attribute = RATINGS_ATTRIBUTES[i]
      value ||= 0
      object[attribute] = Number(value)
    return next(null, object)

@getRating = (id, next) ->
  id = id.toLowerCase()
  exports.getPlayer id, (err, player) ->
    return next(err)  if err
    return next(null, Number(player.rating))

# Returns the maximum rating for a user among that user and his/her alts
@getMaxRating = (id, next) ->
  id = id.toLowerCase()
  redis.zscore RATINGS_MAXKEY, id, (err, rating) ->
    return next(err)  if err
    rating ||= 0
    next(null, Number(rating))

@setRating = (id, newRating, next) =>
  @setRatings([id], [newRating], next)

@setRatings = (idArray, newRatingArray, next) ->
  idArray = idArray.map((id) -> id.toLowerCase())
  multi = redis.multi()
  multi = multi.sadd(USERS_RATED_KEY, idArray)
  for id, i in idArray
    newRating = newRatingArray[i]
    multi = multi.zadd(RATINGS_SUBKEYS['rating'], newRating, id)
  multi.exec (err) ->
    return next(err)  if err
    updateMaxRatings(idArray, next)

@getPlayers = (idArray, next) ->
  idArray = idArray.map((id) -> id.toLowerCase())
  callbacks = idArray.map (id) =>
    (callback) => @getPlayer(id, callback)
  async.parallel(callbacks, next)

@getRatings = (idArray, next) ->
  idArray = idArray.map((id) -> id.toLowerCase())
  exports.getPlayers idArray, (err, players) ->
    return next(err)  if err
    return next(null, players.map((p) -> Number(p.rating)))

@getRank = (id, next) ->
  id = id.toLowerCase()
  redis.zrevrank RATINGS_SUBKEYS['rating'], id, (err, rank) ->
    return next(err)  if err
    return next(null, null)  if !rank?
    return next(null, rank + 1)  # rank starts at 0

@updatePlayer = (id, score, object, next) ->
  id = id.toLowerCase()
  multi = redis.multi()
  attribute = switch score
    when 1 then 'win'
    when 0 then 'lose'
    else 'draw'
  multi = multi.hincrby(RATIOS_SUBKEYS[attribute], id, 1)
  multi = multi.sadd(USERS_RATED_KEY, id)
  for attribute in RATINGS_ATTRIBUTES
    value = object[attribute]
    multi = multi.zadd(RATINGS_SUBKEYS[attribute], value, id)
  multi.exec (err) ->
    return next(err)  if err
    updateMaxRating(id, next)

@updatePlayers = (id, opponentId, score, next) ->
  if score < 0 || score > 1
    return next(new Error("Invalid match result: #{score}"))

  id = id.toLowerCase()
  opponentId = opponentId.toLowerCase()
  opponentScore = 1.0 - score
  exports.getPlayers [id, opponentId], (err, results) =>
    return next(err)  if err
    [player, opponent] = results
    defaultRating = @algorithm.createPlayer().rating
    player.rating ||= defaultRating
    opponent.rating ||= defaultRating
    winnerMatches = [{opponent, score}]
    loserMatches = [{opponent: player, score: opponentScore}]
    newWinner = exports.algorithm.calculate(player, winnerMatches, ALGORITHM_OPTIONS)
    newLoser = exports.algorithm.calculate(opponent, loserMatches, ALGORITHM_OPTIONS)
    async.parallel [
      @updatePlayer.bind(this, id, score, newWinner)
      @updatePlayer.bind(this, opponentId, opponentScore, newLoser)
    ], (err, results) =>
      return next(err)  if err
      @getRatings([id, opponentId], next)

@resetRating = (id, next) ->
  @resetRatings([id], next)

@resetRatings = (idArray, next) ->
  idArray = idArray.map((id) -> id.toLowerCase())
  multi = redis.multi()
  multi = multi.srem(USERS_RATED_KEY, idArray)
  for attribute, key of RATINGS_SUBKEYS
    multi = multi.zrem(key, idArray)
  multi.exec (err) ->
    return next(err)  if err
    updateMaxRatings(idArray, next)

@listRatings = (page = 1, perPage = RATINGS_PER_PAGE, next) ->
  if arguments.length == 2 && typeof perPage == 'function'
    [perPage, next] = [RATINGS_PER_PAGE, perPage]
  page -= 1
  start = page * perPage
  end = start + (perPage - 1)
  redis.zrevrange RATINGS_MAXKEY, start, end, 'WITHSCORES', (err, r) ->
    return next(err)  if err
    array = []
    for i in [0...r.length] by 2
      username = r[i]
      score = Number(r[i + 1])  # redis returns scores as strings
      array.push(username: username, score: score)
    next(null, array)

@getRatio = (id, next) ->
  id = id.toLowerCase()
  multi = redis.multi()
  for attribute, key of RATIOS_SUBKEYS
    multi = multi.hget(key, id)
  multi.exec (err, results) ->
    return next(err)  if err
    hash = {}
    for attribute, i in RATIOS_ATTRIBUTES
      hash[attribute] = Number(results[i]) || 0
    return next(null, hash)
