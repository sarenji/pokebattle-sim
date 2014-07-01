redis = require './redis'
async = require 'async'
alts = require './alts'
@algorithm = require('./elo')
@DECAY_AMOUNT = 5
{LADDER_FORMATS} = require('../shared/conditions')

# Helper to join keys more concisely
join = (keys...) ->
  keys.join(':')

USERS_RATED_KEY = "users:rated"
USERS_ACTIVE_KEY = "users:active"
RATINGS_KEY = "ratings"
RATINGS_ATTRIBUTES = Object.keys(@algorithm.createPlayer())
RATINGS_SUBKEYS = {}
for ladder in LADDER_FORMATS
  RATINGS_SUBKEYS[ladder] = {}
  for attribute in RATINGS_ATTRIBUTES
    RATINGS_SUBKEYS[ladder][attribute] = join(RATINGS_KEY, ladder, attribute)
RATINGS_MAXKEY = "ratings:max"
RATINGS_PER_PAGE = 15

ALGORITHM_OPTIONS =
  systemConstant: 0.2  # Glicko2 tau

@results =
  WIN  : 1
  DRAW : 0.5  # In earlier generations, it's possible to draw.
  LOSE : 0

@setActive = (ladder, idArray, next) ->
  idArray = [idArray]  if idArray not instanceof Array
  idArray = idArray.map((id) -> id.toLowerCase())
  redis.sadd(join(USERS_ACTIVE_KEY, ladder), idArray, next)

RATIOS_KEY = 'ratios'
RATIOS_ATTRIBUTES = Object.keys(@results).map((key) -> key.toLowerCase())
RATIOS_SUBKEYS = {}
for ladder in LADDER_FORMATS
  RATIOS_SUBKEYS[ladder] = {}
  for attribute in RATIOS_ATTRIBUTES
    RATIOS_SUBKEYS[ladder][attribute] = join(RATIOS_KEY, ladder, attribute)

# Used internally by the ratings system to update
# the max rating of user when a rating changes
# Id can either be the actual id, or an alt id
updateMaxRating = (ladder, id, next) =>
  id = alts.getIdOwner(id).toLowerCase()
  alts.listUserAlts id, (err, altNames) =>
    return next(err)  if err
    
    # Retrieve a list of all rating Keys
    ids = (alts.uniqueId(id, name) for name in altNames)
    ids.push(id)

    @getRatings ladder, ids, (err, results) ->
      return next(err)  if err
      redis.zadd(join(RATINGS_MAXKEY, ladder), Math.max(results...), id)
      next(null)

# Update the max ratings for multiple players
updateMaxRatings = (ladder, ids, next) ->
  ops = ids.map (id) ->
    (callback) -> updateMaxRating(ladder, id, callback)
  async.parallel ops, next

@getPlayer = (ladder, id, next) ->
  id = id.toLowerCase()
  multi = redis.multi()
  for attribute in RATINGS_ATTRIBUTES
    multi = multi.zscore(RATINGS_SUBKEYS[ladder][attribute], id)
  multi.exec (err, results) ->
    return next(err)  if err
    object = {}
    for value, i in results
      attribute = RATINGS_ATTRIBUTES[i]
      value ||= 0
      object[attribute] = Number(value)
    return next(null, object)

@getRating = (ladder, id, next) ->
  id = id.toLowerCase()
  exports.getPlayer ladder, id, (err, player) ->
    return next(err)  if err
    return next(null, Number(player.rating))

# Returns the maximum rating for a user among that user and his/her alts
@getMaxRating = (ladder, id, next) ->
  id = id.toLowerCase()
  redis.zscore join(RATINGS_MAXKEY, ladder), id, (err, rating) ->
    return next(err)  if err
    rating ||= 0
    next(null, Number(rating))

@setRating = (ladder, id, newRating, next) =>
  @setRatings(ladder, [id], [newRating], next)

@setRatings = (ladder, idArray, newRatingArray, next) ->
  idArray = idArray.map((id) -> id.toLowerCase())
  multi = redis.multi()
  multi = multi.sadd(join(USERS_RATED_KEY, ladder), idArray)
  for id, i in idArray
    newRating = newRatingArray[i]
    multi = multi.zadd(RATINGS_SUBKEYS[ladder]['rating'], newRating, id)
  multi.exec (err) ->
    return next(err)  if err
    updateMaxRatings(ladder, idArray, next)

@getPlayers = (ladder, idArray, next) ->
  idArray = idArray.map((id) -> id.toLowerCase())
  callbacks = idArray.map (id) =>
    (callback) => @getPlayer(ladder, id, callback)
  async.parallel(callbacks, next)

@getRatings = (ladder, idArray, next) ->
  idArray = idArray.map((id) -> id.toLowerCase())
  exports.getPlayers ladder, idArray, (err, players) ->
    return next(err)  if err
    return next(null, players.map((p) -> Number(p.rating)))

@getRank = (ladder, id, next) ->
  id = id.toLowerCase()
  redis.zrevrank RATINGS_SUBKEYS[ladder]['rating'], id, (err, rank) ->
    return next(err)  if err
    return next(null, null)  if !rank?
    return next(null, rank + 1)  # rank starts at 0

@getRanks = (ladder, idArray, next) ->
  idArray = idArray.map((id) -> id.toLowerCase())
  multi = redis.multi()
  for id in idArray
    multi = multi.zrevrank(RATINGS_SUBKEYS[ladder]['rating'], id)
  multi.exec (err, ranks) ->
    return next(err)  if err
    ranks = ranks.map (rank) ->
      # Rank starts at 0, but it can also be null (doesn't exist).
      if rank? then rank + 1 else null
    next(null, ranks)

@updatePlayer = (ladder, id, score, object, next) ->
  id = id.toLowerCase()
  multi = redis.multi()
  attribute = switch score
    when 1 then 'win'
    when 0 then 'lose'
    else 'draw'
  multi = multi.hincrby(RATIOS_SUBKEYS[ladder][attribute], id, 1)
  multi = multi.sadd(join(USERS_RATED_KEY, ladder), id)
  for attribute in RATINGS_ATTRIBUTES
    value = object[attribute]
    multi = multi.zadd(RATINGS_SUBKEYS[ladder][attribute], value, id)
  multi.exec (err) ->
    return next(err)  if err
    updateMaxRating(ladder, id, next)

@updatePlayers = (ladder, id, opponentId, score, next) ->
  if score < 0 || score > 1
    return next(new Error("Invalid match result: #{score}"))

  id = id.toLowerCase()
  opponentId = opponentId.toLowerCase()
  opponentScore = 1.0 - score
  exports.getPlayers ladder, [id, opponentId], (err, results) =>
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
      @updatePlayer.bind(this, ladder, id, score, newWinner)
      @updatePlayer.bind(this, ladder, opponentId, opponentScore, newLoser)
    ], (err, results) =>
      return next(err)  if err
      @getRatings(ladder, [id, opponentId], next)

@resetRating = (ladder, id, next) ->
  @resetRatings(ladder, [id], next)

@resetRatings = (ladder, idArray, next) ->
  idArray = idArray.map((id) -> id.toLowerCase())
  multi = redis.multi()
  multi = multi.srem(join(USERS_RATED_KEY, ladder), idArray)
  for attribute, key of RATINGS_SUBKEYS[ladder]
    multi = multi.zrem(key, idArray)
  multi.exec (err) ->
    return next(err)  if err
    updateMaxRatings(ladder, idArray, next)

@listRatings = (ladder, page = 1, perPage = RATINGS_PER_PAGE, next) ->
  if arguments.length == 2 && typeof perPage == 'function'
    [perPage, next] = [RATINGS_PER_PAGE, perPage]
  page -= 1
  start = page * perPage
  end = start + (perPage - 1)
  redis.zrevrange join(RATINGS_MAXKEY, ladder), start, end, 'WITHSCORES', (err, r) ->
    return next(err)  if err
    array = []
    for i in [0...r.length] by 2
      username = r[i]
      score = Number(r[i + 1])  # redis returns scores as strings
      array.push(username: username, score: score)
    next(null, array)

@getRatio = (ladder, id, next) ->
  id = id.toLowerCase()
  multi = redis.multi()
  for attribute, key of RATIOS_SUBKEYS[ladder]
    multi = multi.hget(key, id)
  multi.exec (err, results) ->
    return next(err)  if err
    hash = {}
    for attribute, i in RATIOS_ATTRIBUTES
      hash[attribute] = Number(results[i]) || 0
    return next(null, hash)
