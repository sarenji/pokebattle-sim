http = require 'http'
express = require 'express'
require 'express-namespace'
require 'sugar'

request = require 'request'

{BattleServer, ConnectionServer, User} = require './server'

server = new BattleServer()
app = express()
httpServer = http.createServer(app)

# Configuration
app.set("views", "client")
app.use(express.bodyParser())
app.use(express.methodOverride())
app.use(app.router)
app.use(express.static(__dirname + "/public"))
app.use(require('connect-assets')(src: "client"))

PORT = process.env.PORT || 8000
PERSONA_AUDIENCE = "http://localhost:#{PORT}"

# Routing
app.get '/', (req, res) ->
  {PokemonData, MoveData, ItemData} = require './data/bw'
  res.render 'index.jade', {PokemonData, MoveData, ItemData}

# API
app.namespace "/v1/api", ->
  app.get '/pokemon', (req, res) ->
    {PokemonData} = require './data/bw'
    res.json(PokemonData)

userList = []

# Start responding to websocket clients
connections = new ConnectionServer(httpServer, prefix: '/socket')

connections.addEvents
  'send chat': (user, message) ->
    user.broadcast 'update chat', user.toJSON(), message

  # TODO: Dequeue player
  'close': (user) ->
    userList.remove(user)
    user.broadcast 'leave chatroom', user.toJSON()

  ###########
  # BATTLES #
  ###########

  'find battle': (user) ->
    # TODO: Take team from player.
    # TODO: Validate team.
    team = defaultTeam
    server.queuePlayer(user, team)
    if server.queuedPlayers().length >= 2
      server.beginBattles()

  'send move': (user, battleId, moveName) ->
    battle = server.findBattle(battleId)
    if !battle
      user.send 'error', 'ERROR: Battle does not exist'
      return

    battle.makeMove(user, moveName)
  
  'send switch': (user, battleId, toSlot) ->
    battle = server.findBattle(battleId)
    if !battle
      user.send 'error', 'ERROR: Battle does not exist'
      return

    battle.makeSwitch(user, toSlot)

  ##################
  # AUTHENTICATION #
  ##################
  'assert login': (user, assertion) ->
    console.log "verifying with persona"
    url = 'https://verifier.login.persona.org/verify'
    audience = PERSONA_AUDIENCE
    json = {assertion, audience}
    params = {url, json}
    callback = (error, response, body) ->
      if error
        user.send('login fail', "Could not connect to the login server.")
        return
      if body.status != 'okay'
        user.send('login fail', body.reason)
        return
      user._id = body.email
      user.id = generateUsername()
      userList.push(user)
      user.send 'login success', user.toJSON()
      user.send 'list chatroom', userList.map((u) -> u.toJSON())
      user.broadcast 'join chatroom', user.toJSON()
    request.post(params, callback)

  # TODO: socket.off after disconnection

httpServer.listen(PORT)

generateUsername = ->
  {PokemonData} = require './data/bw'
  randomName = (name  for name of PokemonData)
  randomName = randomName[Math.floor(Math.random() * randomName.length)]
  randomName = randomName.split(/\s+/)[0]
  randomName += "Fan" + Math.floor(Math.random() * 10000)
  randomName


# TODO: Implement team builder!
defaultTeam = [
  {
    name: "Pikachu"
    moves: ["Substitute", "Thunderbolt", "Hidden Power", "Grass Knot"]
    item: "Light Ball"
    ability: "Lightningrod"
  }
  {
    name: "Hitmonchan"
    moves: ["Close Combat", "Mach Punch", "Ice Punch", "ThunderPunch"]
    item: "Life Orb"
    ability: "Iron Fist"
  }
  {
    name: "Charizard"
    item: "Choice Specs"
    moves: ["Fire Blast", "Air Slash", "Hidden Power", "Focus Blast"]
    ability: "Blaze"
  }
  {
    name: "Dragonite"
    item: "Leftovers"
    moves: ["Dragon Dance", "Outrage", "Fire Punch", "ExtremeSpeed"]
    ability: "Multiscale"
  }
  {
    name: "Jigglypuff"
    item: "Leftovers"
    moves: ["Sing", "Seismic Toss", "Protect", "Wish"]
    ability: "Cute Charm"
  }
  {
    name: "Haunter"
    item: "Leftovers"
    moves: ["Substitute", "Disable", "Shadow Ball", "Focus Blast"]
    ability: "Levitate"
  }
]
