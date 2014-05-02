redis = require 'redis'

# Connect to redis
if process.env.REDIS_DB_URL
  parts = require("url").parse(process.env.REDIS_DB_URL)
  db = redis.createClient(parts.port, parts.hostname)
  db.auth(parts.auth.split(":")[1])  if parts.auth
else
  db = redis.createClient()

if process.env.NODE_ENV == 'test'
  # Select test database
  db.select(1)

determineShardSize = (next) ->
  return next(determineShardSize.SHARD_SIZE)  if determineShardSize.SHARD_SIZE
  db.config 'get', 'hash-max-zipmap-entries', (err, size) ->
    throw err  if err
    determineShardSize.SHARD_SIZE = size
    next(determineShardSize.SHARD_SIZE)

determineShardSize.SHARD_SIZE = null

db.shard = (command, key, id, args...) ->
  if command[0] != 'h'
    throw new Error('Sharding does not work with non-hashes.')
  id = Number(id)
  determineShardSize (size) ->
    [division, remainder] = [ Math.floor(id / size), (id % size) ]
    key = [ key, division ].join(':')
    db[command](key, remainder, args...)

# Export database variable
module.exports = db
