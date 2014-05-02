redis = require './redis'

ALT_LIMIT = 5
ALTS_KEY = "alts"

# Runs basic username validation for alts
@isAltNameValid = (altName) ->
  return false  if !altName

  altName = altName.trim()
  return false  if altName == ""
  # TODO: check alphanumeric, space, _, -
  return true

# Retrieves a list of alts registered to the user
# next is a callback with args (error, altsList)
@listUserAlts = (userId, next) ->
  redis.lrange "#{userId}:alts", 0, -1, (err, alts) ->
    return next(err)  if err
    next(null, alts)

# Creates an alt for the user with the given id
# next is a callback with args (error, success)
# TODO: Should this use a transaction?
@createAlt = (userId, altName, next) ->
  altListKey = "#{userId}:alts"
  redis.llen altListKey, (err, amount) ->
    return next(err) if err
    if amount >= ALT_LIMIT
      return next(new Error("You have run out of alts. You cannot create another one."))
    redis.hsetnx ALTS_KEY, altName, userId, (err, success) ->
      return next(err) if err
      return next(new Error("This alt name is already in use"))  if not success
      
      # If we got this far, adding the alt succeeded
      # Add it to the list of user's alts, and then call next
      redis.rpush altListKey, altName, ->
        next(null, true)

# Checks if the user owns a particular alt name.
# Always returns true if altName is null (meaning no alt)
@isAltOwnedBy = (userId, altName, next) ->
  return next(undefined, true)  if not altName
  redis.hget ALTS_KEY, altName, (err, assignedUserId) ->
    return next(err)  if err
    next(err, assignedUserId == userId)

# Generates a unique id for a given id + altName combination.
# If altName is null, the original id is returned
@uniqueId = (id, altName) ->
  return id  if not altName
  "#{id}:#{altName}"
