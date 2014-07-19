crypto = require 'crypto'
path = require 'path'
fs = require 'fs'

config = require('./server/config')

cache = {}

cachedVersion = null

S3_ASSET_PREFIX = 'sim/'

get = (src, options = {}) ->
  return src  if config.IS_LOCAL
  return cache[src]  if src of cache && !options.force
  hash = options.fingerprint || getAssetHash(src)
  extName = path.extname(src)
  cache[src] = "#{S3_ASSET_PREFIX}#{src[0...-extName.length]}-#{hash}#{extName}"
  cache[src]

getAssetHash = (src) ->
  contents = fs.readFileSync("public/#{src}")
  crypto.createHash('md5').update(contents).digest('hex')

getAbsolute = (src, options = {}) ->
  prefix = (if config.IS_LOCAL then "" else "//media.pokebattle.com")
  "#{prefix}/#{get(src, options)}"

# Returns a MD5 hash representing the version of the assets.
getVersion = ->
  return cachedVersion  if cachedVersion
  hash = crypto.createHash('md5')
  for jsPath in fs.readdirSync('public/js')
    hash = hash.update(fs.readFileSync("public/js/#{jsPath}"))
  cachedVersion = hash.digest('hex')
  cachedVersion

module.exports = {S3_ASSET_PREFIX, get, getAssetHash, getAbsolute, getVersion}
