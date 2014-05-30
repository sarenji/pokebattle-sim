require './helpers'

{BattleServer} = require('../server/server')
{User} = require('../server/user')
{Conditions, DEFAULT_FORMAT} = require '../shared/conditions'
{Factory} = require './factory'
alts = require('../server/alts')
should = require('should')

generateTeam = ->
  [ Factory("Magikarp")
    Factory("Gyarados")
    Factory('Hitmonchan')
    Factory("Celebi")
    Factory("Blissey")
    Factory("Alakazam") ]

describe 'BattleServer', ->
  it 'can create a new battle', ->
    server = new BattleServer()
    battleId = server.createBattle()
    server.battles.should.have.ownProperty battleId

  it "sends the 'spectateBattle' event for each matched player", (done) ->
    players = [ new User('abc'), new User('def') ]
    spies = []
    for player in players
      spy = @sandbox.spy(player, 'send')
      spies.push(spy)

    server = new BattleServer()
    server.join(players[0])
    server.join(players[1])
    for player in players
      server.queuePlayer(player.id, generateTeam()).should.be.empty
    server.beginBattles (err, ids) ->
      throw new Error(err.message)  if err
      return  if ids.length == 0
      for spy in spies
        spy.calledWith('spectateBattle').should.be.true
      done()

  describe "#queuePlayer", ->
    it "queues players", ->
      server = new BattleServer()
      server.queuePlayer("derp", generateTeam()).should.be.empty
      server.queues[DEFAULT_FORMAT].size().should.equal(1)

    it "does not queue players already queued", ->
      server = new BattleServer()
      server.queuePlayer("derp", generateTeam()).should.be.empty
      server.queuePlayer("derp", generateTeam()).should.be.empty
      server.queues[DEFAULT_FORMAT].size().should.equal(1)

  describe "#getOngoingBattles", ->
    it "returns one object for each queued battle", (done) ->
      server = new BattleServer()
      nBattles = 3
      for i in [1..nBattles]
        server.queuePlayer("#{2*i}", generateTeam()).should.be.empty
        server.queuePlayer("#{(2*i) + 1}", generateTeam()).should.be.empty

      server.beginBattles ->
        server.getOngoingBattles().should.have.length(nBattles)
        done()

  describe "#registerChallenge", ->
    it "registers a challenge to a player", ->
      server = new BattleServer()
      user = new User("Batman")
      other = new User("Robin")
      challengeeId = other.id
      team = generateTeam()
      format = 'xy1000'
      conditions = []

      server.join(user)
      server.join(other)
      server.registerChallenge(user, challengeeId, format, team, conditions)
      server.challenges.should.have.property(user.id)
      server.challenges[user.id].should.have.property(challengeeId)

      challenge = server.challenges[user.id][challengeeId]
      challenge.should.have.property("team")
      challenge.should.have.property("format")
      challenge.should.have.property("conditions")
      challenge.team.should.equal(team)
      challenge.format.should.equal(format)
      challenge.conditions.should.equal(conditions)

    it "does not override old challenges", ->
      server = new BattleServer()
      user = new User("Batman")
      other = new User("Robin")
      challengeeId = other.id
      team = generateTeam()
      format = 'xy1000'
      diffFormat = 'xy500'
      diffTeam = generateTeam()
      diffTeam[0] = Factory("Celebi")

      server.join(user)
      server.join(other)
      server.registerChallenge(user, challengeeId, format, team)
      server.registerChallenge(user, challengeeId, diffFormat, diffTeam)

      challenge = server.challenges[user.id][challengeeId]
      challenge.format.should.equal(format)
      challenge.team.should.equal(team)

    it "returns an error if the team is invalid", ->
      server = new BattleServer()
      user = new User("Batman")
      other = new User("Robin")
      challengeeId = other.id
      format = 'xy1000'

      server.join(user)
      server.join(other)
      mock = @sandbox.mock(user).expects('error').once()
      team = []
      server.registerChallenge(user, other.id, format, team)
      mock.verify()

    it "returns an error if the team is over 1000 PBV with 1000 PBV clause", ->
      server = new BattleServer()
      user = new User("Batman")
      other = new User("Robin")
      format = 'xy1000'
      team = generateTeam()
      team[0] = Factory("Arceus", moves: [ "Recover" ])
      conditions = [ Conditions.PBV_1000 ]

      server.join(user)
      server.join(other)
      mock = @sandbox.mock(user).expects('error').once()
      server.registerChallenge(user, other.id, format, team, conditions)
      mock.verify()

    it "returns an error on a rated challenge", ->
      server = new BattleServer()
      user = new User("Batman")
      other = new User("Robin")
      format = 'xy1000'
      team = generateTeam()
      conditions = [ Conditions.RATED_BATTLE ]

      server.join(user)
      server.join(other)
      mock = @sandbox.mock(user).expects('error').once()
      server.registerChallenge(user, other.id, format, team, conditions)
      mock.verify()

    it "returns an error if the format is invalid", ->
      server = new BattleServer()
      user = new User("Batman")
      other = new User("Robin")
      challengeeId = other.id
      team = generateTeam()
      format = "UNRELEASED INFERNO RED AND WEIRD YELLOWISH GREEN"
      conditions = []

      server.join(user)
      server.join(other)
      mock = @sandbox.mock(user).expects('error').once()
      server.registerChallenge(user, other.id, format, team, conditions)
      mock.verify()

    it "returns an error if the challengee is offline", ->
      server = new BattleServer()
      user = new User("Batman")
      other = new User("Robin")
      challengeeId = other.id
      team = generateTeam()
      format = 'xy1000'
      conditions = []

      server.join(user)
      # server.join(other)  # Other must be offline.
      mock = @sandbox.mock(user).expects('error').once()
      server.registerChallenge(user, other.id, format, team, conditions)
      mock.verify()

    it "returns an error if you challenge yourself", ->
      server = new BattleServer()
      user = new User("Batman")
      other = new User("Robin")
      challengeeId = other.id
      team = generateTeam()
      format = 'xy1000'
      conditions = []

      server.join(user)
      mock = @sandbox.mock(user).expects('error').once()
      server.registerChallenge(user, user.id, format, team, conditions)
      mock.verify()

    it "sends an error if a challenge already exists for that pair", ->
      server = new BattleServer()
      user = new User("Batman")
      other = new User("Robin")
      challengeeId = other.id
      team = generateTeam()
      format = 'xy1000'
      conditions = []

      server.join(user)
      server.join(other)
      server.registerChallenge(user, other.id, format, team, conditions)

      mock = @sandbox.mock(other).expects('error').once()
      server.registerChallenge(other, user.id, format, team, conditions)
      mock.verify()

    it "sends a 'challenge' event to the challengee", ->
      server = new BattleServer()
      user = new User("Batman")
      other = new User("Robin")
      challengeeId = other.id
      team = generateTeam()
      format = 'xy1000'
      conditions = []

      server.join(user)
      server.join(other)
      spy = @sandbox.spy(server.users, 'send')
      spy.withArgs(challengeeId, 'challenge', user.id,
        format, conditions)
      server.registerChallenge(user, challengeeId, format, team, conditions)
      spy.withArgs(challengeeId, 'challenge', user.id,
        format, conditions).calledOnce.should.be.true

    it "returns an error if the server is locked down", ->
      server = new BattleServer()
      user = new User("Batman")
      other = new User("Robin")
      challengeeId = other.id
      format = 'xy1000'
      team = generateTeam()
      conditions = [ Conditions.PBV_1000 ]

      server.join(user)
      server.join(other)
      mock = @sandbox.mock(user).expects('error').once()
      server.lockdown()
      server.registerChallenge(user, other.id, format, team, conditions)
      mock.verify()

  describe "#cancelChallenge", ->
    it "sends a 'cancelChallenge' to both the challengee and challenger", ->
      server = new BattleServer()
      user = new User("Batman")
      other = new User("Robin")
      challengeeId = other.id
      team = generateTeam()
      format = 'xy1000'
      conditions = []

      server.join(user)
      server.join(other)
      spy = @sandbox.spy(server.users, 'send')
      spy.withArgs(challengeeId, 'cancelChallenge', user.id)
      spy.withArgs(user.id, 'cancelChallenge', challengeeId)
      server.registerChallenge(user, challengeeId, format, team, conditions)
      server.cancelChallenge(user, challengeeId)
      spy.withArgs(challengeeId, 'cancelChallenge', user.id)
        .calledOnce.should.be.true
      spy.withArgs(user.id, 'cancelChallenge', challengeeId)
        .calledOnce.should.be.true

    it "removes the challenge from the internal hash", ->
      server = new BattleServer()
      user = new User("Batman")
      other = new User("Robin")
      challengeeId = other.id
      team = generateTeam()
      format = 'xy1000'
      conditions = []

      server.join(user)
      server.join(other)
      server.registerChallenge(user, other.id, format, team, conditions)
      should.exist server.challenges[user.id][other.id]
      server.cancelChallenge(user, other.id)
      should.not.exist server.challenges[user.id][other.id]

  describe "#rejectChallenge", ->
    it "sends a 'rejectChallenge' to the challengee and challenger", ->
      server = new BattleServer()
      user = new User("Batman")
      other = new User("Robin")
      challengeeId = other.id
      team = generateTeam()
      format = 'xy1000'
      conditions = []

      server.join(user)
      server.join(other)
      server.registerChallenge(user, other.id, format, team, conditions)

      spy = @sandbox.spy(server.users, 'send')
      spy.withArgs(challengeeId, 'rejectChallenge', user.id)
      spy.withArgs(user.id, 'rejectChallenge', challengeeId)
      server.rejectChallenge(other, user.id)
      spy.withArgs(challengeeId, 'rejectChallenge', user.id)
        .calledOnce.should.be.true
      spy.withArgs(user.id, 'rejectChallenge', challengeeId)
        .calledOnce.should.be.true

    it "removes the challenge from the internal hash", ->
      server = new BattleServer()
      user = new User("Batman")
      other = new User("Robin")
      challengeeId = other.id
      team = generateTeam()
      format = 'xy1000'
      conditions = []

      server.join(user)
      server.join(other)
      server.registerChallenge(user, other.id, format, team, conditions)
      should.exist server.challenges[user.id][other.id]
      server.rejectChallenge(other, user.id)
      should.not.exist server.challenges[user.id][other.id]

    it "returns an error if no such challenge exists", ->
      server = new BattleServer()
      user = new User("Batman")
      other = new User("Robin")
      challengeeId = other.id
      team = generateTeam()
      format = 'xy1000'
      conditions = []

      server.join(user)
      server.join(other)
      server.registerChallenge(user, other.id, format, team, conditions)
      mock = @sandbox.mock(other).expects('error').once()
      server.rejectChallenge(other, "bogus dude")
      mock.verify()

  describe "#acceptChallenge", ->
    initServer = ->
      @server = new BattleServer()
      @user = new User("Batman")
      @other = new User("Robin")
      @server.join(@user)
      @server.join(@other)

    it "creates a battle with the teams given by both players", ->
      initServer.call(this)
      team = generateTeam()
      format = 'xy1000'
      conditions = []
      
      @server.registerChallenge(@user, @other.id, format, team, conditions)
      mock = @sandbox.mock(@server).expects('createBattle').once()
      @server.acceptChallenge(@other, @user.id, team)
      mock.verify()

    it "returns an error to a player if their team is invalid", ->
      initServer.call(this)
      team = generateTeam()
      format = 'xy1000'
      conditions = []

      @server.registerChallenge(@user, @other.id, format, team, conditions)
      mock = @sandbox.mock(@other).expects('error').once()
      @server.acceptChallenge(@other, @user.id, [])
      mock.verify()

    it "returns an error to a player if their team violates clauses", ->
      initServer.call(this)
      team = generateTeam()
      acceptTeam = generateTeam()
      acceptTeam[0] = Factory("Mewtwo", moves: [ "Psychic" ])
      format = 'xy1000'
      conditions = [ Conditions.PBV_1000 ]

      @server.registerChallenge(@user, @other.id, format, team, conditions)
      mock = @sandbox.mock(@other).expects('error').once()
      @server.acceptChallenge(@other, @user.id, acceptTeam)
      mock.verify()

    it "removes the challenge from the internal hash", ->
      initServer.call(this)
      team = generateTeam()
      format = 'xy1000'
      conditions = []

      @server.registerChallenge(@user, @other.id, format, team, conditions)
      should.exist @server.challenges[@user.id][@other.id]
      @server.acceptChallenge(@other, @user.id, team)
      should.not.exist @server.challenges[@user.id][@other.id]

    it "sends a 'challengeSuccess' event to both players", ->
      initServer.call(this)
      challengeeId = @other.id
      team = generateTeam()
      format = 'xy1000'
      conditions = []

      @server.registerChallenge(@user, challengeeId, format, team, conditions)

      spy = @sandbox.spy(@server.users, 'send')
      spy.withArgs(@user.id, 'challengeSuccess', challengeeId)
      spy.withArgs(@challengeeId, 'challengeSuccess', @user.id)
      @server.acceptChallenge(@other, @user.id, team)
      spy.withArgs(@user.id, 'challengeSuccess', challengeeId).calledOnce.should.be.true
      spy.withArgs(challengeeId, 'challengeSuccess', @user.id).calledOnce.should.be.true

    it "returns an error if no such challenge exists", ->
      initServer.call(this)
      team = generateTeam()
      format = 'xy1000'
      conditions = []

      @server.registerChallenge(@user, @other.id, format, team, conditions)
      mock = @sandbox.mock(@other).expects('error').once()
      @server.acceptChallenge(@other, "bogus dude", team)
      mock.verify()

    it "overrides the user's name with the alt name in battle", ->
      initServer.call(this)
      team = generateTeam()
      format = 'xy1000'
      conditions = []

      @server.registerChallenge(@user, @other.id, format, team, conditions, "Bruce Wayne")
      battleId = @server.acceptChallenge(@other, @user.id, team, "Jason Todd")
      battle = @server.findBattle(battleId)
      battle.battle.playerNames.should.eql ["Bruce Wayne", "Jason Todd"]

    it "sets the rating key to be the unique alt id if there is an alt", ->
      initServer.call(this)
      team = generateTeam()
      format = 'xy1000'
      conditions = []

      @server.registerChallenge(@user, @other.id, format, team, conditions, "Bruce Wayne")
      battleId = @server.acceptChallenge(@other, @user.id, team, "Jason Todd")
      battle = @server.findBattle(battleId)

      battle.battle.getPlayer("Batman").ratingKey.should.equal alts.uniqueId(@user.id, "Bruce Wayne")
      battle.battle.getPlayer("Robin").ratingKey.should.equal alts.uniqueId(@other.id, "Jason Todd")

  describe "#leave", ->
    it "removes challenges by that player", ->
      server = new BattleServer()
      user = new User("Batman")
      other = new User("Robin")
      challengeeId = other.id
      team = generateTeam()
      format = 'xy1000'
      conditions = []

      server.join(user)
      server.join(other)
      server.registerChallenge(user, other.id, format, team, conditions)
      should.exist server.challenges[user.id]
      should.exist server.challenges[user.id][other.id]
      server.leave(user)
      should.not.exist server.challenges[user.id]

    it "removes challenges to that player", ->
      server = new BattleServer()
      user = new User("Batman")
      other = new User("Robin")
      challengeeId = other.id
      team = generateTeam()
      format = 'xy1000'
      conditions = []

      server.join(user)
      server.join(other)
      server.registerChallenge(other, user.id, format, team, conditions)
      should.exist server.challenges[other.id]
      should.exist server.challenges[other.id][user.id]
      server.leave(user)
      should.exist server.challenges[other.id]
      should.not.exist server.challenges[other.id][user.id]

  describe "#lockdown", ->
    it "cancels all challenges", ->
      server = new BattleServer()
      user = new User("Batman")
      other = new User("Robin")
      challengeeId = other.id
      challengerId = user.id
      team = generateTeam()
      format = 'xy1000'
      conditions = []

      server.join(user)
      server.join(other)
      server.registerChallenge(other, user.id, format, team, conditions)
      should.exist server.challenges[challengeeId]
      should.exist server.challenges[challengeeId][challengerId]
      server.lockdown()
      should.not.exist server.challenges[challengeeId]

  describe "#validateTeam", ->
    it "returns non-empty if given anything that's not an array", ->
      server = new BattleServer()
      server.validateTeam().should.not.be.empty

    it "returns empty if given a non-empty array containing Pokemon", ->
      server = new BattleServer()
      server.validateTeam(generateTeam()).should.be.empty

    it "returns non-empty if given an empty array", ->
      server = new BattleServer()
      server.validateTeam([]).should.not.be.empty

    it "returns non-empty if a team member is not a valid Pokemon", ->
      server = new BattleServer()
      invalidPokemon = {}
      server.validateTeam([ invalidPokemon ]).should.not.be.empty

    it "returns non-empty if a team member has a fake species name", ->
      server = new BattleServer()
      team = generateTeam()
      team[0] = {species: "NOTREALMON"}
      server.validateTeam(team).should.not.be.empty

    it "returns non-empty if a team member has no moveset", ->
      server = new BattleServer()
      team = generateTeam()
      team[0] = Factory("Hitmonchan", moves: null)
      server.validateTeam(team).should.not.be.empty

    it "returns non-empty if a team member has an empty moveset", ->
      server = new BattleServer()
      team = generateTeam()
      team[0] = Factory("Hitmonchan", moves: [])
      server.validateTeam(team).should.not.be.empty

    it "returns non-empty if a team member has a bogus moveset", ->
      server = new BattleServer()
      team = generateTeam()
      team[0] = Factory("Hitmonchan", moves: true)
      server.validateTeam(team).should.not.be.empty
      team[0] = Factory("Hitmonchan", moves: ["Super Powerful Punch"])
      server.validateTeam(team).should.not.be.empty

    it "returns non-empty if a team member has an illegal moveset", ->
      server = new BattleServer()
      team = generateTeam()
      team[0] = Factory("Raichu", moves: [ "Volt Tackle", "Encore" ])
      server.validateTeam(team, 'bw').should.not.be.empty

    # TODO: 4 is a magic constant
    it "returns non-empty if a pokemon has more than 4 moves", ->
      server = new BattleServer()
      team = generateTeam()
      team[0] = Factory "Hitmonchan",
        moves:  [
                  "Ice Punch"
                  "Fire Punch"
                  "Close Combat"
                  "Mach Punch"
                  "Rapid Spin"
                ]
      server.validateTeam(team).should.not.be.empty

    it "returns non-empty if a pokemon has a move it can't learn", ->
      server = new BattleServer()
      team = generateTeam()
      team[0] = Factory("Magikarp", moves: [ "Fissure" ])
      server.validateTeam(team).should.not.be.empty

    it "returns non-empty if a pokemon has a fake move", ->
      server = new BattleServer()
      team = generateTeam()
      team[0] = Factory("Magikarp", moves: [ "Splash", "Armageddon" ])
      server.validateTeam(team).should.not.be.empty

    it "returns non-empty if a pokemon has an ability it can't have", ->
      server = new BattleServer()
      team = generateTeam()
      team[0] = Factory("Magikarp", ability: "Wonder Guard")
      server.validateTeam(team).should.not.be.empty

    it "returns non-empty if a pokemon has a bogus ability", ->
      server = new BattleServer()
      team = generateTeam()
      team[0] = Factory("Magikarp", ability: "Being Batman")
      server.validateTeam(team).should.not.be.empty

    it "returns empty if a pokemon has a hidden ability", ->
      server = new BattleServer()
      team = generateTeam()
      team[0] = Factory("Cloyster", ability: "Overcoat")
      server.validateTeam(team).should.be.empty

    it "returns non-empty if a pokemon has a level below 1", ->
      server = new BattleServer()
      team = generateTeam()
      team[0] = Factory("Magikarp", level: 0)
      server.validateTeam(team).should.not.be.empty

    it "returns non-empty if a pokemon has a bogus level", ->
      server = new BattleServer()
      team = generateTeam()
      team[0] = Factory("Magikarp", level: "hi")
      server.validateTeam(team).should.not.be.empty

    # TODO: 100 is a magic constant
    it "returns non-empty if a pokemon has a level over 100", ->
      server = new BattleServer()
      team = generateTeam()
      team[0] = Factory("Magikarp", level: 101)
      server.validateTeam(team).should.not.be.empty

    it "returns non-empty if a pokemon has an iv below 0", ->
      server = new BattleServer()
      team = generateTeam()
      team[0] = Factory("Magikarp", ivs: { hp: -1 })
      server.validateTeam(team).should.not.be.empty

    it "returns non-empty if a pokemon has an iv above 31", ->
      server = new BattleServer()
      team = generateTeam()
      team[0] = Factory("Magikarp", ivs: { hp: 32 })
      server.validateTeam(team).should.not.be.empty

    it "returns non-empty if a pokemon has bogus ivs", ->
      server = new BattleServer()
      team = generateTeam()
      team[0] = Factory("Magikarp", ivs: true)
      server.validateTeam(team).should.not.be.empty

    it "returns non-empty if a pokemon has an ev below 0", ->
      server = new BattleServer()
      team = generateTeam()
      team[0] = Factory("Magikarp", evs: { hp: -1 })
      server.validateTeam(team).should.not.be.empty

    it "returns non-empty if a pokemon has an ev above 255", ->
      server = new BattleServer()
      team = generateTeam()
      team[0] = Factory("Magikarp", evs: { hp: 256 })
      server.validateTeam(team).should.not.be.empty

    it "returns non-empty if a pokemon has an ev total above 510", ->
      server = new BattleServer()
      team = generateTeam()
      team[0] = Factory("Magikarp", evs: { hp: 255, defense: 255, speed: 255 })
      server.validateTeam(team).should.not.be.empty

    it "returns non-empty if a pokemon has bogus evs", ->
      server = new BattleServer()
      team = generateTeam()
      team[0] = Factory("Magikarp", evs: true)
      server.validateTeam(team).should.not.be.empty

    it "returns non-empty if a pokemon has an invalid gender", ->
      server = new BattleServer()
      team = generateTeam()
      team[0] = Factory("Metagross", gender: "Alien")
      server.validateTeam(team).should.not.be.empty

    it "returns non-empty if a pokemon has a gender it can't have", ->
      server = new BattleServer()
      team = generateTeam()
      team[0] = Factory("Metagross", gender: "F")
      server.validateTeam(team).should.not.be.empty

      team = generateTeam()
      team[0] = Factory("Blissey", gender: "M")
      server.validateTeam(team).should.not.be.empty

      team = generateTeam()
      team[0] = Factory("Gallade", gender: "F")
      server.validateTeam(team).should.not.be.empty

    it "returns non-empty if a pokemon has a bogus forme", ->
      server = new BattleServer()
      team = generateTeam()
      team[0] = Factory("Blissey", forme: "Super Ultra Mega Blissey")
      server.validateTeam(team).should.not.be.empty

    it "returns non-empty if a pokemon has a battle-only forme", ->
      server = new BattleServer()
      team = generateTeam()
      team[0] = Factory("Meloetta", forme: "pirouette", moves: ["Relic Song"])
      server.validateTeam(team).should.not.be.empty

    it "returns non-empty if a pokemon cannot have its forme"

    it "returns non-empty if the format is fake", ->
      server = new BattleServer()
      server.validateTeam(generateTeam(), 'bogusformat').should.not.be.empty

    it "returns non-empty if a pokemon's nickname matches another species", ->
      server = new BattleServer()
      team = generateTeam()
      team[0].name = "Latios"
      server.validateTeam(team).should.not.be.empty

    it "returns non-empty if a pokemon's nickname is blank", ->
      server = new BattleServer()
      team = generateTeam()
      team[0].name = ""
      server.validateTeam(team).should.not.be.empty

    it "returns non-empty if a pokemon's nickname contains illegal chars", ->
      server = new BattleServer()
      team = generateTeam()
      team[0].name = "some chars \uFE20 are illegal"
      server.validateTeam(team).should.not.be.empty

    it "returns non-empty if a pokemon's nickname is past a certain length", ->
      server = new BattleServer()
      team = generateTeam()
      team[0].name = ("A"  for x in [0...50]).join('')
      server.validateTeam(team).should.not.be.empty

  describe "#beginBattles", ->
    it "creates a battle per pair", (done) ->
      server = new BattleServer()
      for i in [1..4]
        server.join(new User("user#{i}"))  
        server.queuePlayer("user#{i}", generateTeam())
      server.beginBattles (err, battleIds) ->
        battleIds.length.should.equal(2)
        done()

  describe "users", ->
    it "are recorded to be playing in which battles", (done) ->
      server = new BattleServer()
      [ user1, user2, user3 ] = [ "a", "b", "c" ]
      server.queuePlayer(user1, generateTeam()).should.be.empty
      server.queuePlayer(user2, generateTeam()).should.be.empty
      server.queuePlayer(user3, generateTeam()).should.be.empty
      server.beginBattles (err, battleIds) ->
        server.getUserBattles(user1).should.eql(battleIds)
        server.getUserBattles(user2).should.eql(battleIds)
        server.getUserBattles(user3).should.be.empty
        done()

    it "no longer records battles once they end", (done) ->
      server = new BattleServer()
      [ user1, user2, user3 ] = [ "a", "b", "c" ]
      server.queuePlayer(user1, generateTeam()).should.be.empty
      server.queuePlayer(user2, generateTeam()).should.be.empty
      server.queuePlayer(user3, generateTeam()).should.be.empty
      server.beginBattles (err, battleIds) ->
        for battleId in battleIds
          battle = server.findBattle(battleId)
          battle.endBattle()
        server.getUserBattles(user1).should.be.empty
        server.getUserBattles(user2).should.be.empty
        server.getUserBattles(user3).should.be.empty
        done()

  describe "a battle", ->
    beforeEach (done) ->
      @server = new BattleServer()
      [ @user1, @user2, @user3 ] = [ "a", "b", "c" ]
      @server.queuePlayer(@user1, generateTeam()).should.be.empty
      @server.queuePlayer(@user2, generateTeam()).should.be.empty
      @server.queuePlayer(@user3, generateTeam()).should.be.empty
      @server.queuedPlayers().should.have.length(3)
      @server.beginBattles (err, battleIds) =>
        @battleIds = battleIds
        @relevantUser = @server.findBattle(@battleIds[0]).battle.playerIds[0]
        done()

    it "removes from user battles if ended", ->
      @server.getUserBattles(@relevantUser).should.not.be.empty
      battle = @server.findBattle(@battleIds[0])
      battle.endBattle()
      @server.getUserBattles(@user1).should.be.empty
      @server.getUserBattles(@user2).should.be.empty
      @server.getUserBattles(@user3).should.be.empty

    it "removes from user battles if forfeited", ->
      @server.getUserBattles(@relevantUser).should.not.be.empty
      battle = @server.findBattle(@battleIds[0])
      battle.forfeit(@relevantUser)
      @server.getUserBattles(@user1).should.be.empty
      @server.getUserBattles(@user2).should.be.empty
      @server.getUserBattles(@user3).should.be.empty
