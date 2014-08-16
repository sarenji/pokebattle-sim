crypto = require 'crypto'
path = require 'path'
fs = require 'fs'

config = require('./server/config')

cachedVersion = null
cachedAssetHash = null
cachedFingerprints = {}

S3_ASSET_PREFIX = 'sim/'

get = (src, options = {}) ->
  return src  if config.IS_LOCAL
  hash = options.fingerprint || getFingerprint(src)
  extName = path.extname(src)
  "#{S3_ASSET_PREFIX}#{src[0...-extName.length]}-#{hash}#{extName}"

getFingerprint = (src) ->
  return cachedFingerprints[src]  if cachedFingerprints[src]
  contents = fs.readFileSync("public/#{src}")
  fingerprint = crypto.createHash('md5').update(contents).digest('hex')
  cachedFingerprints[src] = fingerprint
  fingerprint

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

# Returns a hash of asset hashes, keyed by filename
asHash = ->
  return cachedAssetHash  if cachedAssetHash
  cachedAssetHash = {}
  for jsPath in fs.readdirSync('public/js')
    jsPath = "js/#{jsPath}"
    cachedAssetHash[jsPath] = getFingerprint(jsPath)
  cachedAssetHash

module.exports = {S3_ASSET_PREFIX, get, asHash, getAbsolute, getVersion}
