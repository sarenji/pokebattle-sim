http = require 'http'
express = require 'express'
levelup = require 'level'
require 'express-namespace'
require 'sugar'

request = require 'request'

{BattleServer, ConnectionServer} = require './server'

server = new BattleServer()
app = express()
httpServer = http.createServer(app)

# Configuration
app.set("views", "client")
app.use(express.logger())
app.use(express.compress())  # gzip
app.use(express.bodyParser())
app.use(express.methodOverride())
app.use(app.router)
app.use(express.static(__dirname + "/public"))

process.env.NODE_ENV ||= "development"

PORT = process.env.PORT || 8000
PERSONA_AUDIENCE = switch process.env.NODE_ENV
  when "production"
    "http://battletower.herokuapp.com:80"
  else
    "http://localhost:#{PORT}"

# User store
db = levelup('./pokebattle-db', valueEncoding: 'json')

# Routing
app.get '/', (req, res) ->
  {PokemonData, MoveData, ItemData} = require './data/bw'
  local = process.env.NODE_ENV in [ 'development', 'test' ]
  res.render 'index.jade', {local, PokemonData, MoveData, ItemData}

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
    return  unless user.isLoggedIn() && message?.replace(/\s+/, '').length > 0
    user.broadcast 'update chat', user.toJSON(), message

  'send battle chat': (user, battleId, message) ->
    return  unless user.isLoggedIn() && message?.replace(/\s+/, '').length > 0
    battle = server.findBattle(battleId)
    if !battle
      user.send 'error', 'ERROR: Battle does not exist'
      return

    user.broadcast 'update battle chat', battleId, user.toJSON(), message

  # TODO: Dequeue player
  'close': (user) ->
    userList.remove((u) -> u == user)
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
      battles = server.beginBattles()
      for battle in battles
        [ first, second, id ] = battle
        message = """#{first.id} vs. #{second.id}!
        <span class="fake_link spectate" data-battle-id="#{id}">Watch</span>"""
        connections.broadcast('raw message', message)

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

  'spectate battle': (user, battleId) ->
    battle = server.findBattle(battleId)
    if !battle
      user.send 'error', 'ERROR: Battle does not exist'
      return

    battle.addSpectator(user)

  'forfeit': (user, battleId) ->
    battle = server.findBattle(battleId)
    if !battle
      user.send 'error', 'ERROR: Battle does not exist'
      return

    battle.forfeit(user)

  ##################
  # AUTHENTICATION #
  ##################
  'assert login': (user, assertion) ->
    assertLogin(user, assertion)

  # TODO: socket.off after disconnection

httpServer.listen(PORT)

generateUsername = ->
  {PokemonData} = require './data/bw'
  randomName = (name  for name of PokemonData)
  randomName = randomName[Math.floor(Math.random() * randomName.length)]
  randomName = randomName.split(/\s+/)[0]
  randomName += "Fan" + Math.floor(Math.random() * 10000)
  randomName

assertLogin = (user, assertion) ->
  if process.env.NODE_ENV not in [ 'development', 'test' ]
    console.log "verifying with persona"
    url = 'https://verifier.login.persona.org/verify'
    audience = PERSONA_AUDIENCE
    json = {assertion, audience}
    params = {url, json}
    request.post params, (err, response, body) ->
      if err
        user.send('login fail', "Could not connect to the login server.")
        return
      if body.status != 'okay'
        user.send('login fail', body.reason)
        return
      email = body.email
      db.get email, (err, properties) ->
        if err?.name == 'NotFoundError'
          console.log "Could not find user: #{email}"
          db.put email, email: email, (err) ->
            if err
              user.send('login fail', "#{err.name}: #{err.message}")
              return
        else if err
          user.send('login fail', "#{err.name}: #{err.message}")
          return
        user.id = generateUsername()
        user.email = email
        userList.push(user)
        user.send 'login success', user.toJSON()
        user.send 'list chatroom', userList.map((u) -> u.toJSON())
        user.broadcast 'join chatroom', user.toJSON()
  else
    console.log "mocking login"
    user.id = generateUsername()
    user.email = "test@pokebattle.com"
    userList.push(user)
    user.send 'login success', user.toJSON()
    user.send 'list chatroom', userList.map((u) -> u.toJSON())
    user.broadcast 'join chatroom', user.toJSON()

# TODO: Implement team builder!
defaultTeam = [
  {
    name: "Pikachu"
    moves: ["Substitute", "Thunderbolt", "Hidden Power", "Grass Knot"]
    item: "Light Ball"
    ability: "Lightningrod"
    gender: "F"
  }
  {
    name: "Hitmonchan"
    moves: ["Close Combat", "Mach Punch", "Ice Punch", "ThunderPunch"]
    item: "Life Orb"
    ability: "Iron Fist"
    gender: "M"
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
