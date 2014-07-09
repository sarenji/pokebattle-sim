require './helpers'

{BattleServer} = require('../server/server')
{Conditions, DEFAULT_FORMAT} = require '../shared/conditions'
{Protocol} = require '../shared/protocol'
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
    server = new BattleServer()
    players = []
    players.push server.findOrCreateUser(id: 1, name: 'abc', @stubSpark())
    players.push server.findOrCreateUser(id: 2, name: 'def', @stubSpark())

    spies = []
    for player in players
      spy = @sandbox.spy(player, 'send')
      spies.push(spy)

    for player in players
      server.queuePlayer(player.name, generateTeam()).should.be.empty
    server.beginBattles (err, ids) ->
      throw new Error(err.message)  if err
      return  if ids.length == 0
      for spy in spies
        spy.calledWith('spectateBattle').should.be.true
      done()

  describe "#queuePlayer", ->
    it "queues players", ->
      server = new BattleServer()
      derp = server.findOrCreateUser(id: 1, name: 'derp', @stubSpark())
      server.queuePlayer(derp.name, generateTeam()).should.be.empty
      server.queues[DEFAULT_FORMAT].size().should.equal(1)

    it "does not queue players already queued", ->
      server = new BattleServer()
      derp = server.findOrCreateUser(id: 1, name: 'derp', @stubSpark())
      server.queuePlayer(derp.name, generateTeam()).should.be.empty
      server.queuePlayer(derp.name, generateTeam()).should.be.empty
      server.queues[DEFAULT_FORMAT].size().should.equal(1)

  describe "#getOngoingBattles", ->
    it "returns one object for each queued battle", (done) ->
      server = new BattleServer()
      nBattles = 3
      for i in [1..nBattles]
        first = 2 * i
        second = (2 * i) + 1
        server.findOrCreateUser(id: first, name: String(first), @stubSpark())
        server.findOrCreateUser(id: second, name: String(second), @stubSpark())
        server.queuePlayer(String(first), generateTeam()).should.be.empty
        server.queuePlayer(String(second), generateTeam()).should.be.empty

      server.beginBattles ->
        server.getOngoingBattles().should.have.length(nBattles)
        done()

  describe "#registerChallenge", ->
    it "registers a challenge to a player", ->
      server = new BattleServer()
      user = server.findOrCreateUser(id: 1, name: "Batman", @stubSpark())
      other = server.findOrCreateUser(id: 2, name: "Robin", @stubSpark())
      team = generateTeam()
      format = 'xy1000'
      conditions = []

      server.registerChallenge(user, other.name, format, team, conditions)
      server.challenges.should.have.property(user.name)
      server.challenges[user.name].should.have.property(other.name)

      challenge = server.challenges[user.name][other.name]
      challenge.should.have.property("team")
      challenge.should.have.property("format")
      challenge.should.have.property("conditions")
      challenge.team.should.equal(team)
      challenge.format.should.equal(format)
      challenge.conditions.should.equal(conditions)

    it "does not override old challenges", ->
      server = new BattleServer()
      user = server.findOrCreateUser(id: 1, name: "Batman", @stubSpark())
      other = server.findOrCreateUser(id: 2, name: "Robin", @stubSpark())
      team = generateTeam()
      format = 'xy1000'
      diffFormat = 'xy500'
      diffTeam = generateTeam()
      diffTeam[0] = Factory("Celebi")

      server.registerChallenge(user, other.name, format, team)
      server.registerChallenge(user, other.name, diffFormat, diffTeam)

      challenge = server.challenges[user.name][other.name]
      challenge.format.should.equal(format)
      challenge.team.should.equal(team)

    it "returns an error if the team is invalid", ->
      server = new BattleServer()
      user = server.findOrCreateUser(id: 1, name: "Batman", @stubSpark())
      other = server.findOrCreateUser(id: 2, name: "Robin", @stubSpark())
      format = 'xy1000'

      mock = @sandbox.mock(user).expects('error').once()
      team = []
      server.registerChallenge(user, other.name, format, team)
      mock.verify()

    it "returns an error if the team is over 1000 PBV with 1000 PBV clause", ->
      server = new BattleServer()
      user = server.findOrCreateUser(id: 1, name: "Batman", @stubSpark())
      other = server.findOrCreateUser(id: 2, name: "Robin", @stubSpark())
      format = 'xy1000'
      team = generateTeam()
      team[0] = Factory("Arceus", moves: [ "Recover" ])
      conditions = [ Conditions.PBV_1000 ]

      mock = @sandbox.mock(user).expects('error').once()
      server.registerChallenge(user, other.name, format, team, conditions)
      mock.verify()

    it "returns an error on a rated challenge", ->
      server = new BattleServer()
      user = server.findOrCreateUser(id: 1, name: "Batman", @stubSpark())
      other = server.findOrCreateUser(id: 2, name: "Robin", @stubSpark())
      format = 'xy1000'
      team = generateTeam()
      conditions = [ Conditions.RATED_BATTLE ]

      mock = @sandbox.mock(user).expects('error').once()
      server.registerChallenge(user, other.name, format, team, conditions)
      mock.verify()

    it "returns an error if the format is invalid", ->
      server = new BattleServer()
      user = server.findOrCreateUser(id: 1, name: "Batman", @stubSpark())
      other = server.findOrCreateUser(id: 2, name: "Robin", @stubSpark())
      team = generateTeam()
      format = "UNRELEASED INFERNO RED AND WEIRD YELLOWISH GREEN"
      conditions = []

      mock = @sandbox.mock(user).expects('error').once()
      server.registerChallenge(user, other.name, format, team, conditions)
      mock.verify()

    it "returns an error if the challengee is offline", ->
      server = new BattleServer()
      user = server.findOrCreateUser(id: 1, name: "Batman", @stubSpark())
      team = generateTeam()
      format = 'xy1000'
      conditions = []

      mock = @sandbox.mock(user).expects('error').once()
      server.registerChallenge(user, "husk", format, team, conditions)
      mock.verify()

    it "returns an error if you challenge yourself", ->
      server = new BattleServer()
      user = server.findOrCreateUser(id: 1, name: "Batman", @stubSpark())
      other = server.findOrCreateUser(id: 2, name: "Robin", @stubSpark())
      team = generateTeam()
      format = 'xy1000'
      conditions = []

      mock = @sandbox.mock(user).expects('error').once()
      server.registerChallenge(user, user.name, format, team, conditions)
      mock.verify()

    it "sends an error if a challenge already exists for that pair", ->
      server = new BattleServer()
      user = server.findOrCreateUser(id: 1, name: "Batman", @stubSpark())
      other = server.findOrCreateUser(id: 2, name: "Robin", @stubSpark())
      team = generateTeam()
      format = 'xy1000'
      conditions = []

      server.registerChallenge(user, other.name, format, team, conditions)

      mock = @sandbox.mock(other).expects('error').once()
      server.registerChallenge(other, user.name, format, team, conditions)
      mock.verify()

    it "sends a 'challenge' event to the challengee", ->
      server = new BattleServer()
      user = server.findOrCreateUser(id: 1, name: "Batman", @stubSpark())
      other = server.findOrCreateUser(id: 2, name: "Robin", @stubSpark())
      team = generateTeam()
      format = 'xy1000'
      conditions = []

      otherSpy = @sandbox.spy(other, 'send')
      otherSpy.withArgs('challenge', user.name, format, conditions)

      server.registerChallenge(user, other.name, format, team, conditions)

      otherSpy.withArgs('challenge', user.name, format, conditions)
        .calledOnce.should.be.true

    it "returns an error if the server is locked down", ->
      server = new BattleServer()
      user = server.findOrCreateUser(id: 1, name: "Batman", @stubSpark())
      other = server.findOrCreateUser(id: 2, name: "Robin", @stubSpark())
      format = 'xy1000'
      team = generateTeam()
      conditions = [ Conditions.PBV_1000 ]

      mock = @sandbox.mock(user).expects('error').once()
      server.lockdown()
      server.registerChallenge(user, other.name, format, team, conditions)
      mock.verify()

  describe "#cancelChallenge", ->
    it "sends a 'cancelChallenge' to both the challengee and challenger", ->
      server = new BattleServer()
      user = server.findOrCreateUser(id: 1, name: "Batman", @stubSpark())
      other = server.findOrCreateUser(id: 2, name: "Robin", @stubSpark())
      team = generateTeam()
      format = 'xy1000'
      conditions = []

      userSpy = @sandbox.spy(user, 'send')
      userSpy.withArgs('cancelChallenge', other.name)
      otherSpy = @sandbox.spy(other, 'send')
      otherSpy.withArgs('cancelChallenge', user.name)

      server.registerChallenge(user, other.name, format, team, conditions)
      server.cancelChallenge(user, other.name)

      userSpy.withArgs('cancelChallenge', other.name).calledOnce.should.be.true
      otherSpy.withArgs('cancelChallenge', user.name).calledOnce.should.be.true

    it "removes the challenge from the internal hash", ->
      server = new BattleServer()
      user = server.findOrCreateUser(id: 1, name: "Batman", @stubSpark())
      other = server.findOrCreateUser(id: 2, name: "Robin", @stubSpark())
      team = generateTeam()
      format = 'xy1000'
      conditions = []

      server.registerChallenge(user, other.name, format, team, conditions)
      should.exist server.challenges[user.name][other.name]
      server.cancelChallenge(user, other.name)
      should.not.exist server.challenges[user.name][other.name]

  describe "#rejectChallenge", ->
    it "sends a 'rejectChallenge' to the challengee and challenger", ->
      server = new BattleServer()
      user = server.findOrCreateUser(id: 1, name: "Batman", @stubSpark())
      other = server.findOrCreateUser(id: 2, name: "Robin", @stubSpark())
      team = generateTeam()
      format = 'xy1000'
      conditions = []

      server.registerChallenge(user, other.name, format, team, conditions)

      userSpy = @sandbox.spy(user, 'send')
      userSpy.withArgs('rejectChallenge', other.name)
      otherSpy = @sandbox.spy(other, 'send')
      otherSpy.withArgs('rejectChallenge', user.name)

      server.rejectChallenge(other, user.name)

      userSpy.withArgs('rejectChallenge', other.name).calledOnce.should.be.true
      otherSpy.withArgs('rejectChallenge', user.name).calledOnce.should.be.true

    it "removes the challenge from the internal hash", ->
      server = new BattleServer()
      user = server.findOrCreateUser(id: 1, name: "Batman", @stubSpark())
      other = server.findOrCreateUser(id: 2, name: "Robin", @stubSpark())
      team = generateTeam()
      format = 'xy1000'
      conditions = []

      server.registerChallenge(user, other.name, format, team, conditions)
      should.exist server.challenges[user.name][other.name]
      server.rejectChallenge(other, user.name)
      should.not.exist server.challenges[user.name][other.name]

    it "returns an error if no such challenge exists", ->
      server = new BattleServer()
      user = server.findOrCreateUser(id: 1, name: "Batman", @stubSpark())
      other = server.findOrCreateUser(id: 2, name: "Robin", @stubSpark())
      team = generateTeam()
      format = 'xy1000'
      conditions = []

      server.registerChallenge(user, other.name, format, team, conditions)
      mock = @sandbox.mock(other).expects('error').once()
      server.rejectChallenge(other, "bogus dude")
      mock.verify()

  describe "#acceptChallenge", ->
    initServer = ->
      @server = new BattleServer()
      @user = @server.findOrCreateUser(id: 1, name: "Batman", @stubSpark())
      @other = @server.findOrCreateUser(id: 2, name: "Robin", @stubSpark())

    it "creates a battle with the teams given by both players", ->
      initServer.call(this)
      team = generateTeam()
      format = 'xy1000'
      conditions = []
      
      @server.registerChallenge(@user, @other.name, format, team, conditions)
      mock = @sandbox.mock(@server).expects('createBattle').once()
      @server.acceptChallenge(@other, @user.name, team)
      mock.verify()

    it "returns an error to a player if their team is invalid", ->
      initServer.call(this)
      team = generateTeam()
      format = 'xy1000'
      conditions = []

      @server.registerChallenge(@user, @other.name, format, team, conditions)
      mock = @sandbox.mock(@other).expects('error').once()
      @server.acceptChallenge(@other, @user.name, [])
      mock.verify()

    it "returns an error to a player if their team violates clauses", ->
      initServer.call(this)
      team = generateTeam()
      acceptTeam = generateTeam()
      acceptTeam[0] = Factory("Mewtwo", moves: [ "Psychic" ])
      format = 'xy1000'
      conditions = [ Conditions.PBV_1000 ]

      @server.registerChallenge(@user, @other.name, format, team, conditions)
      mock = @sandbox.mock(@other).expects('error').once()
      @server.acceptChallenge(@other, @user.name, acceptTeam)
      mock.verify()

    it "removes the challenge from the internal hash", ->
      initServer.call(this)
      team = generateTeam()
      format = 'xy1000'
      conditions = []

      @server.registerChallenge(@user, @other.name, format, team, conditions)
      should.exist @server.challenges[@user.name][@other.name]
      @server.acceptChallenge(@other, @user.name, team)
      should.not.exist @server.challenges[@user.name][@other.name]

    it "sends a 'challengeSuccess' event to both players", ->
      initServer.call(this)
      team = generateTeam()
      format = 'xy1000'
      conditions = []

      userSpy = @sandbox.spy(@user, 'send')
      userSpy.withArgs('challengeSuccess', @other.name)
      otherSpy = @sandbox.spy(@other, 'send')
      otherSpy.withArgs('challengeSuccess', @user.name)

      @server.registerChallenge(@user, @other.name, format, team, conditions)
      @server.acceptChallenge(@other, @user.name, team)

      userSpy.withArgs('challengeSuccess', @other.name).calledOnce.should.be.true
      otherSpy.withArgs('challengeSuccess', @user.name).calledOnce.should.be.true

    it "returns an error if no such challenge exists", ->
      initServer.call(this)
      team = generateTeam()
      format = 'xy1000'
      conditions = []

      @server.registerChallenge(@user, @other.name, format, team, conditions)
      mock = @sandbox.mock(@other).expects('error').once()
      @server.acceptChallenge(@other, "bogus dude", team)
      mock.verify()

    it "overrides the user's name with the alt name in battle", ->
      initServer.call(this)
      team = generateTeam()
      format = 'xy1000'
      conditions = []

      @server.registerChallenge(@user, @other.name, format, team, conditions, "Bruce Wayne")
      battleId = @server.acceptChallenge(@other, @user.name, team, "Jason Todd")
      battle = @server.findBattle(battleId)
      battle.battle.playerNames.should.eql ["Bruce Wayne", "Jason Todd"]

    it "sets the rating key to be the unique alt id if there is an alt", ->
      initServer.call(this)
      team = generateTeam()
      format = 'xy1000'
      conditions = []

      @server.registerChallenge(@user, @other.name, format, team, conditions, "Bruce Wayne")
      battleId = @server.acceptChallenge(@other, @user.name, team, "Jason Todd")
      battle = @server.findBattle(battleId)

      battle.battle.getPlayer("Batman").ratingKey.should.equal alts.uniqueId(@user.name, "Bruce Wayne")
      battle.battle.getPlayer("Robin").ratingKey.should.equal alts.uniqueId(@other.name, "Jason Todd")

  describe "#leave", ->
    it "removes challenges by that player", ->
      server = new BattleServer()
      user = server.findOrCreateUser(id: 1, name: "Batman", spark = @stubSpark())
      other = server.findOrCreateUser(id: 2, name: "Robin", @stubSpark())
      team = generateTeam()
      format = 'xy1000'
      conditions = []

      server.registerChallenge(user, other.name, format, team, conditions)
      should.exist server.challenges[user.name]
      should.exist server.challenges[user.name][other.name]
      server.leave(spark)
      should.not.exist server.challenges[user.name]

    it "removes challenges to that player", ->
      server = new BattleServer()
      user = server.findOrCreateUser(id: 1, name: "Batman", spark = @stubSpark())
      other = server.findOrCreateUser(id: 2, name: "Robin", @stubSpark())
      team = generateTeam()
      format = 'xy1000'
      conditions = []

      server.registerChallenge(other, user.name, format, team, conditions)
      should.exist server.challenges[other.name]
      should.exist server.challenges[other.name][user.name]
      server.leave(spark)
      should.exist server.challenges[other.name]
      should.not.exist server.challenges[other.name][user.name]

  describe "#lockdown", ->
    it "cancels all challenges", ->
      server = new BattleServer()
      user = server.findOrCreateUser(id: 1, name: "Batman", @stubSpark())
      other = server.findOrCreateUser(id: 2, name: "Robin", @stubSpark())
      team = generateTeam()
      format = 'xy1000'
      conditions = []

      server.registerChallenge(other, user.name, format, team, conditions)
      should.exist server.challenges[other.name]
      should.exist server.challenges[other.name][user.name]
      server.lockdown()
      should.not.exist server.challenges[other.name]

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
        server.findOrCreateUser(id: i, name: "user#{i}", @stubSpark())
        server.queuePlayer("user#{i}", generateTeam())
      server.beginBattles (err, battleIds) ->
        battleIds.length.should.equal(2)
        done()

  describe "users", ->
    it "are recorded to be playing in which battles", (done) ->
      server = new BattleServer()
      [ user1, user2, user3 ] = [ "a", "b", "c" ]
      for name, i in [ user1, user2, user3 ]
        server.findOrCreateUser(id: i, name: name, @stubSpark())
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
      for name, i in [ user1, user2, user3 ]
        server.findOrCreateUser(id: i, name: name, @stubSpark())
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

    it "can join multiple times", ->
      server = new BattleServer()
      server.findOrCreateUser(id: 1, name: "hey", spark1 = @stubSpark())
      server.join(spark1)
      (=>
        server.findOrCreateUser(id: 1, name: "hey", spark2 = @stubSpark())
        server.join(spark2)
      ).should.not.throw()

    it "records battles they're under an alt in", (done) ->
      server = new BattleServer()
      [ user1, user2 ] = [ "a", "b" ]
      for name, i in [ user1, user2 ]
        server.findOrCreateUser(id: i, name: name, @stubSpark())
      server.queuePlayer(user1, generateTeam(), null, 'alt1').should.be.empty
      server.queuePlayer(user2, generateTeam(), null, 'alt2').should.be.empty
      server.beginBattles (err, battleIds) ->
        server.getUserBattles(user1).should.not.be.empty
        server.getUserBattles(user2).should.not.be.empty
        done()

    it "auto-rejoin battles they're under an alt in", (done) ->
      server = new BattleServer()
      [ user1, user2 ] = [ "a", "b" ]
      server.findOrCreateUser(id: 1, name: user1, spark1 = @stubSpark())
      server.findOrCreateUser(id: 2, name: user2, spark2 = @stubSpark())
      server.queuePlayer(user1, generateTeam(), null, 'alt1').should.be.empty
      server.queuePlayer(user2, generateTeam(), null, 'alt2').should.be.empty
      server.beginBattles (err, battleIds) =>
        [battleId] = battleIds
        battle = server.findBattle(battleId).battle

        # test spark1
        spy = @sandbox.spy(battle, 'tellPlayer').withArgs(user1, Protocol.RECEIVE_TEAM)
        server.join(spark1)
        spy.calledOnce.should.be.true
        battle.tellPlayer.restore()

        # test spark2
        spy = @sandbox.spy(battle, 'tellPlayer').withArgs(user2, Protocol.RECEIVE_TEAM)
        server.join(spark2)
        spy.calledOnce.should.be.true
        battle.tellPlayer.restore()
        done()

    it "automatically leaves a battle when leaving the server", (done) ->
      server = new BattleServer()
      [ user1, user2 ] = [ "a", "b" ]
      server.findOrCreateUser(id: 1, name: user1, spark1 = @stubSpark())
      server.findOrCreateUser(id: 2, name: user2, spark2 = @stubSpark())
      server.join(spark1)
      server.join(spark2)
      server.queuePlayer(user1, generateTeam(), null, 'alt1').should.be.empty
      server.queuePlayer(user2, generateTeam(), null, 'alt2').should.be.empty
      server.beginBattles (err, battleIds) =>
        [battleId] = battleIds
        battle = server.findBattle(battleId).battle

        # test spark1
        spy = @sandbox.spy(battle, 'removeSpectator').withArgs(spark1)
        broadcastSpy = @sandbox.spy(battle, 'broadcast')
        broadcastSpy = broadcastSpy.withArgs('leaveBattle', battle.id, 'alt1')
        server.leave(spark1)
        spy.calledOnce.should.be.true
        broadcastSpy.calledOnce.should.be.true
        battle.removeSpectator.restore()
        battle.broadcast.restore()

        # test spark2
        spy = @sandbox.spy(battle, 'removeSpectator').withArgs(spark2)
        broadcastSpy = @sandbox.spy(battle, 'broadcast')
        broadcastSpy = broadcastSpy.withArgs('leaveBattle', battle.id, 'alt2')
        server.leave(spark2)
        spy.calledOnce.should.be.true
        broadcastSpy.calledOnce.should.be.true
        battle.removeSpectator.restore()
        battle.broadcast.restore()
        done()

  describe "a battle", ->
    beforeEach (done) ->
      @server = new BattleServer()
      [ @user1, @user2, @user3 ] = [ "a", "b", "c" ]
      for name, i in [ @user1, @user2, @user3 ]
        @server.findOrCreateUser(id: i, name: name, @stubSpark())
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
