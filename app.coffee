http = require 'http'
express = require 'express'
redis = require 'redis'
bcrypt = require 'bcrypt'
async = require 'async'
flash = require 'connect-flash'
require 'express-namespace'
require 'sugar'

request = require 'request'

{BattleServer, ConnectionServer} = require './server'

server = new BattleServer()
app = express()
httpServer = http.createServer(app)

# Variables
process.env.NODE_ENV ||= "development"
PORT = process.env.PORT || 8000

# Connect to redis
if process.env.REDIS_DB_URL
  parts = require("url").parse(process.env.REDIS_DB_URL)
  db = redis.createClient(parts.port, parts.hostname)
  db.auth(parts.auth.split(":")[1])  if parts.auth
else
  db = redis.createClient()

# Configuration
app.set("views", "client")
app.use(express.logger())
app.use(express.compress())  # gzip
app.use(express.bodyParser())
app.use(express.cookieParser(process.env.SECRET_KEY || 'very secure key'))
app.use(express.session(cookie: { maxAge: 60000 }))
app.use(flash())
app.use(express.methodOverride())
app.use(app.router)
app.use(express.static(__dirname + "/public"))

# Routing
app.get '/', (req, res) ->
  {SpeciesData, FormeData, MoveData, ItemData} = require './data/bw'
  local = process.env.NODE_ENV in [ 'development', 'test' ]
  res.render 'index.jade', {local, SpeciesData, FormeData, MoveData, ItemData}

app.get '/splash', (req, res) ->
  res.render 'splash.jade',
    messages: req.flash('info')
    errors: req.flash('error')

app.post '/subscribe', (req, res) ->
  email = req.body.email

  # Validate email
  if not /@/.test(email)
    req.flash('error', 'You did not enter a valid email!')
    res.redirect('/splash')
    return

  # Add to subscriptions
  db.sadd "subscriptions", email, (err, added) ->
    if err
      console.error(err)
      req.flash('error', 'Something went wrong! Try again?')
    else if added
      req.flash('info', 'You will now be notified when PokeBattle is released!')
    else
      req.flash('info', 'You are already signed up!')
    res.redirect('/splash')

# API
app.namespace "/v1/api", ->
  app.get '/pokemon', (req, res) ->
    {SpeciesData} = require './data/bw'
    res.json(SpeciesData)

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

    # TODO: Make nicer interface
    for player in battle.battle.players
      continue  if player.user == user
      player.send('update battle chat', battleId, user.toJSON(), message)
    for spectator in battle.battle.spectators
      continue  if spectator == user
      spectator.send('update battle chat', battleId, user.toJSON(), message)

  # TODO: Dequeue player
  'close': (user) ->
    userList.remove((u) -> u == user)
    user.broadcast 'leave chatroom', user.toJSON()

  ###########
  # BATTLES #
  ###########

  'find battle': (user) ->
    # TODO: Take team from player.
    team = defaultTeam.clone()
    if !server.validateTeam(team)
      user.send("error", "Your team is invalid!")
      return
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

  'arrange team': (user, battleId, arrangement) ->
    battle = server.findBattle(battleId)
    if !battle
      user.send 'error', 'ERROR: Battle does not exist'
      return

    battle.arrangeTeam(user, arrangement)

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
  'login': (user, params = {}) ->
    {email, password} = params
    login(user, email, password)

  'register': (user, params) ->
    {username, email, password} = params
    email = email.toLowerCase()
    errors = []
    if !username || username.length < 6
      errors.push 'Your username must be at least 6 characters.'
    if username && /[^a-zA-Z0-9\-_]/.test(username)
      errors.push 'Your username cannot include non-alphanumeric characters.'
    if !email || !/\@/.test(email)
      errors.push 'Invalid email address.'
    if /\:/.test(email)
      errors.push 'Email addresses cannot include colon characters.'
    if !password || password.length < 8
      errors.push 'Your password must be at least 8 characters.'

    if errors.length > 0
      user.send('register error', errors)
      return

    async.parallel
      emailExists: (done) ->
        db.sismember("users", email, done)
      usernameExists: (done) ->
        db.sismember("names", username, done)
    , (err, results) ->
      if err
        console.err(err)
        user.send('register error', 'Oops, something on our end went wrong! Let us know.')
        return

      # Notify user if the email or username already exists.
      {emailExists, usernameExists} = results
      if usernameExists || emailExists
        errors = []
        errors.push('This username is already in use.')  if usernameExists
        errors.push('This email is already in use.')  if emailExists
        user.send('register error', errors)
        return

      # Save to global database of users (emails) and names (usernames)
      db.multi()
        .sadd("users", email)
        .sadd("names", username)
        .exec (err) ->
          if err
            console.err(err)
            user.send('register error', 'Oops, something on our end went wrong! Let us know.')
            return

          # Hash password and store it in users:{email}:password
          bcrypt.hash password, 8, (err, hashedPassword) ->
            if err
              console.err(err)
              user.send('register error', 'Oops, something on our end went wrong! Let us know.')
              return
            db.multi()
              .set("users:#{email}:password", hashedPassword)
              .rpush("users:#{email}:names", username)
              .exec (err) ->
                if err
                  console.err(err)
                  user.send('register error', 'Oops, something on our end went wrong! Let us know.')
                  return
                # Automatically login.
                login(user, email, password)
                user.send('register success')

  # TODO: socket.off after disconnection

httpServer.listen(PORT)

generateUsername = ->
  {SpeciesData} = require './data/bw'
  randomName = (name  for name of SpeciesData)
  randomName = randomName[Math.floor(Math.random() * randomName.length)]
  randomName = randomName.split(/\s+/)[0]
  randomName += "Fan" + Math.floor(Math.random() * 10000)
  randomName

login = (user, email, password) ->
  if process.env.NODE_ENV in [ 'development', 'test' ]
    loginSuccess(user, "test@pokebattle.com")
  else
    email = email.toLowerCase().replace(/:/g, '')
    db.get "users:#{email}:password", (err, hashedPassword) ->
      if err
        console.err(err)
        user.send('login fail', "You entered the wrong username or password.")
        return

      bcrypt.compare password, hashedPassword, (err, res) ->
        if res
          db.lindex "users:#{email}:names", 0, (err, username) ->
            if err
              console.err(err)
              user.send('login fail', "Something went wrong. Try again.")
              return
            user.id = username
            loginSuccess(user, email)
        else
          user.send('login fail', "You entered the wrong username or password.")

loginSuccess = (user, email) ->
  user.id ||= generateUsername()
  user.email = email
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
    name: "Gengar"
    item: "Leftovers"
    moves: ["Substitute", "Disable", "Shadow Ball", "Focus Blast"]
    ability: "Levitate"
  }
]
