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

# Export database variable
module.exports = db
