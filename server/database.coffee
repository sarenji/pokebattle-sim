if process.env.POKEBATTLE_ENV == 'api'
  # For some reason throwing an error will prevent an error from happening.
  # If you console.log here, then you can see this module is included twice.
  throw new Error("API should not connect to DB.")

redis = switch process.env.NODE_ENV
  when 'test' then require 'redis-mock'
  else             require 'redis'

# Connect to redis
if process.env.REDIS_DB_URL
  parts = require("url").parse(process.env.REDIS_DB_URL)
  db = redis.createClient(parts.port, parts.hostname)
  db.auth(parts.auth.split(":")[1])  if parts.auth
else
  db = redis.createClient()

# Export database variable
module.exports = db
