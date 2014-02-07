require './helpers'

{BattleServer} = require('../server/server')
gen = require('../server/generations')
{User} = require('../server/user')
{Conditions} = require '../server/conditions'
{Factory} = require './factory'
should = require('should')

describe 'BattleServer', ->
  it 'can create a new battle', ->
    server = new BattleServer()
    battleId = server.createBattle()
    server.battles.should.have.ownProperty battleId

  it "sends the 'spectate battle' event for each matched player", (done) ->
    players = [ new User('abc'), new User('def') ]
    spies = []
    for player in players
      spy = @sandbox.spy(player, 'send')
      spies.push(spy)

    server = new BattleServer()
    server.join(players[0])
    server.join(players[1])
    for player in players
      server.queuePlayer(player.id, [Factory('Hitmonchan')])
    server.beginBattles (err, ids) ->
      throw new Error(err.message)  if err
      return  if ids.length == 0
      for spy in spies
        spy.calledWith('spectate battle').should.be.true
      done()

  describe "#queuePlayer", ->
    it "queues players", ->
      server = new BattleServer()
      server.queuePlayer("derp", [ Factory("Magikarp") ])
      server.queues[gen.DEFAULT_GENERATION].size().should.equal(1)

    it "does not queue null players", ->
      server = new BattleServer()
      server.queuePlayer(null, [ Factory("Magikarp") ])
      server.queues[gen.DEFAULT_GENERATION].size().should.equal(0)

    it "does not queue players already queued", ->
      server = new BattleServer()
      server.queuePlayer("derp", [ Factory("Magikarp") ])
      server.queuePlayer("derp", [ Factory("Magikarp") ])
      server.queues[gen.DEFAULT_GENERATION].size().should.equal(1)

  describe "#registerChallenge", ->
    it "registers a challenge to a player", ->
      server = new BattleServer()
      user = new User("Batman")
      other = new User("Robin")
      challengeeId = other.id
      team = [ Factory("Magikarp") ]
      generation = 'xy'
      conditions = []

      server.join(user)
      server.join(other)
      server.registerChallenge(user, challengeeId, generation, team, conditions)
      server.challenges.should.have.property(user.id)
      server.challenges[user.id].should.have.property(challengeeId)

      challenge = server.challenges[user.id][challengeeId]
      challenge.should.have.property("team")
      challenge.should.have.property("generation")
      challenge.should.have.property("conditions")
      challenge.team.should.equal(team)
      challenge.generation.should.equal(generation)
      challenge.conditions.should.equal(conditions)

    it "does not override old challenges", ->
      server = new BattleServer()
      user = new User("Batman")
      other = new User("Robin")
      challengeeId = other.id
      team = [ Factory("Magikarp") ]
      generation = 'xy'
      diffGeneration = 'bw'
      diffTeam = [ Factory("Celebi") ]

      server.join(user)
      server.join(other)
      server.registerChallenge(user, challengeeId, generation, team)
      server.registerChallenge(user, challengeeId, diffGeneration, diffTeam)

      challenge = server.challenges[user.id][challengeeId]
      challenge.generation.should.equal(generation)
      challenge.team.should.equal(team)

    it "returns an error if the team is invalid", ->
      server = new BattleServer()
      user = new User("Batman")
      other = new User("Robin")
      challengeeId = other.id
      generation = 'xy'

      server.join(user)
      server.join(other)
      mock = @sandbox.mock(user).expects('error').once()
      team = []
      server.registerChallenge(user, other.id, generation, team)
      mock.verify()

    it "returns an error if the team is over 1000 PBV with 1000 PBV clause", ->
      server = new BattleServer()
      user = new User("Batman")
      other = new User("Robin")
      challengeeId = other.id
      generation = 'xy'
      team = [ Factory("Arceus", moves: [ "Recover" ]) ]
      conditions = [ Conditions.PBV_1000 ]

      server.join(user)
      server.join(other)
      mock = @sandbox.mock(user).expects('error').once()
      server.registerChallenge(user, other.id, generation, team, conditions)
      mock.verify()

    it "returns an error if the generation is invalid", ->
      server = new BattleServer()
      user = new User("Batman")
      other = new User("Robin")
      challengeeId = other.id
      team = [ Factory("Magikarp") ]
      generation = "UNRELEASED INFERNO RED AND WEIRD YELLOWISH GREEN"
      conditions = []

      server.join(user)
      server.join(other)
      mock = @sandbox.mock(user).expects('error').once()
      server.registerChallenge(user, other.id, generation, team, conditions)
      mock.verify()

    it "returns an error if the challengee is offline", ->
      server = new BattleServer()
      user = new User("Batman")
      other = new User("Robin")
      challengeeId = other.id
      team = [ Factory("Magikarp") ]
      generation = 'xy'
      conditions = []

      server.join(user)
      # server.join(other)  # Other must be offline.
      mock = @sandbox.mock(user).expects('error').once()
      server.registerChallenge(user, other.id, generation, team, conditions)
      mock.verify()

    it "returns an error if you challenge yourself", ->
      server = new BattleServer()
      user = new User("Batman")
      other = new User("Robin")
      challengeeId = other.id
      team = [ Factory("Magikarp") ]
      generation = 'xy'
      conditions = []

      server.join(user)
      mock = @sandbox.mock(user).expects('error').once()
      server.registerChallenge(user, user.id, generation, team, conditions)
      mock.verify()

    it "sends an error if a challenge already exists for that pair", ->
      server = new BattleServer()
      user = new User("Batman")
      other = new User("Robin")
      challengeeId = other.id
      team = [ Factory("Magikarp") ]
      generation = 'xy'
      conditions = []

      server.join(user)
      server.join(other)
      server.registerChallenge(user, other.id, generation, team, conditions)

      mock = @sandbox.mock(other).expects('error').once()
      server.registerChallenge(other, user.id, generation, team, conditions)
      mock.verify()

    it "sends a 'challenge' event to the challengee", ->
      server = new BattleServer()
      user = new User("Batman")
      other = new User("Robin")
      challengeeId = other.id
      team = [ Factory("Magikarp") ]
      generation = 'xy'
      conditions = []

      server.join(user)
      server.join(other)
      spy = @sandbox.spy(server.users, 'send')
      spy.withArgs(challengeeId, 'challenge', user.id,
        generation, conditions)
      server.registerChallenge(user, challengeeId, generation, team, conditions)
      spy.withArgs(challengeeId, 'challenge', user.id,
        generation, conditions).calledOnce.should.be.true

  describe "#cancelChallenge", ->
    it "sends a 'cancel challenge' to both the challengee and challenger", ->
      server = new BattleServer()
      user = new User("Batman")
      other = new User("Robin")
      challengeeId = other.id
      team = [ Factory("Magikarp") ]
      generation = 'xy'
      conditions = []

      server.join(user)
      server.join(other)
      spy = @sandbox.spy(server.users, 'send')
      spy.withArgs(challengeeId, 'cancelChallenge', user.id)
      spy.withArgs(user.id, 'cancelChallenge', challengeeId)
      server.registerChallenge(user, challengeeId, generation, team, conditions)
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
      team = [ Factory("Magikarp") ]
      generation = 'xy'
      conditions = []

      server.join(user)
      server.join(other)
      server.registerChallenge(user, other.id, generation, team, conditions)
      should.exist server.challenges[user.id][other.id]
      server.cancelChallenge(user, other.id)
      should.not.exist server.challenges[user.id][other.id]

  describe "#rejectChallenge", ->
    it "sends a 'rejectChallenge' to the challengee and challenger", ->
      server = new BattleServer()
      user = new User("Batman")
      other = new User("Robin")
      challengeeId = other.id
      team = [ Factory("Magikarp") ]
      generation = 'xy'
      conditions = []

      server.join(user)
      server.join(other)
      server.registerChallenge(user, other.id, generation, team, conditions)

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
      team = [ Factory("Magikarp") ]
      generation = 'xy'
      conditions = []

      server.join(user)
      server.join(other)
      server.registerChallenge(user, other.id, generation, team, conditions)
      should.exist server.challenges[user.id][other.id]
      server.rejectChallenge(other, user.id)
      should.not.exist server.challenges[user.id][other.id]

    it "returns an error if no such challenge exists", ->
      server = new BattleServer()
      user = new User("Batman")
      other = new User("Robin")
      challengeeId = other.id
      team = [ Factory("Magikarp") ]
      generation = 'xy'
      conditions = []

      server.join(user)
      server.join(other)
      server.registerChallenge(user, other.id, generation, team, conditions)
      mock = @sandbox.mock(other).expects('error').once()
      server.rejectChallenge(other, "bogus dude")
      mock.verify()

  describe "#acceptChallenge", ->
    it "creates a battle with the teams given by both players", ->
      server = new BattleServer()
      user = new User("Batman")
      other = new User("Robin")
      challengeeId = other.id
      team = [ Factory("Magikarp") ]
      generation = 'xy'
      conditions = []

      server.join(user)
      server.join(other)
      server.registerChallenge(user, other.id, generation, team, conditions)
      mock = @sandbox.mock(server).expects('createBattle').once()
      server.acceptChallenge(other, user.id, team)
      mock.verify()

    it "returns an error to a player if their team is invalid", ->
      server = new BattleServer()
      user = new User("Batman")
      other = new User("Robin")
      challengeeId = other.id
      team = [ Factory("Magikarp") ]
      generation = 'xy'
      conditions = []

      server.join(user)
      server.join(other)
      server.registerChallenge(user, other.id, generation, team, conditions)
      mock = @sandbox.mock(other).expects('error').once()
      server.acceptChallenge(other, user.id, [])
      mock.verify()

    it "removes the challenge from the internal hash", ->
      server = new BattleServer()
      user = new User("Batman")
      other = new User("Robin")
      challengeeId = other.id
      team = [ Factory("Magikarp") ]
      generation = 'xy'
      conditions = []

      server.join(user)
      server.join(other)
      server.registerChallenge(user, other.id, generation, team, conditions)
      should.exist server.challenges[user.id][other.id]
      server.acceptChallenge(other, user.id, team)
      should.not.exist server.challenges[user.id][other.id]

    it "sends a 'challengeSuccess' event to both players", ->
      server = new BattleServer()
      user = new User("Batman")
      other = new User("Robin")
      challengeeId = other.id
      team = [ Factory("Magikarp") ]
      generation = 'xy'
      conditions = []

      server.join(user)
      server.join(other)
      server.registerChallenge(user, challengeeId, generation, team, conditions)

      spy = @sandbox.spy(server.users, 'send')
      spy.withArgs(user.id, 'challengeSuccess', challengeeId)
      spy.withArgs(challengeeId, 'challengeSuccess', user.id)
      server.acceptChallenge(other, user.id, team)
      spy.withArgs(user.id, 'challengeSuccess', challengeeId).calledOnce.should.be.true
      spy.withArgs(challengeeId, 'challengeSuccess', user.id).calledOnce.should.be.true

    it "returns an error if no such challenge exists", ->
      server = new BattleServer()
      user = new User("Batman")
      other = new User("Robin")
      challengeeId = other.id
      team = [ Factory("Magikarp") ]
      generation = 'xy'
      conditions = []

      server.join(user)
      server.join(other)
      server.registerChallenge(user, other.id, generation, team, conditions)
      mock = @sandbox.mock(other).expects('error').once()
      server.acceptChallenge(other, "bogus dude", team)
      mock.verify()

  describe "#leave", ->
    it "removes challenges by that player", ->
      server = new BattleServer()
      user = new User("Batman")
      other = new User("Robin")
      challengeeId = other.id
      team = [ Factory("Magikarp") ]
      generation = 'xy'
      conditions = []

      server.join(user)
      server.join(other)
      server.registerChallenge(user, other.id, generation, team, conditions)
      should.exist server.challenges[user.id]
      should.exist server.challenges[user.id][other.id]
      server.leave(user)
      should.not.exist server.challenges[user.id]

    it "removes challenges to that player", ->
      server = new BattleServer()
      user = new User("Batman")
      other = new User("Robin")
      challengeeId = other.id
      team = [ Factory("Magikarp") ]
      generation = 'xy'
      conditions = []

      server.join(user)
      server.join(other)
      server.registerChallenge(other, user.id, generation, team, conditions)
      should.exist server.challenges[other.id]
      should.exist server.challenges[other.id][user.id]
      server.leave(user)
      should.exist server.challenges[other.id]
      should.not.exist server.challenges[other.id][user.id]


  describe "#validateTeam", ->
    it "returns non-empty if given anything that's not an array", ->
      server = new BattleServer()
      server.validateTeam().should.not.be.empty

    it "returns empty if given a non-empty array containing Pokemon", ->
      server = new BattleServer()
      server.validateTeam([ Factory("Hitmontop") ]).should.be.empty

    it "returns non-empty if given an empty array", ->
      server = new BattleServer()
      server.validateTeam([]).should.not.be.empty

    it "returns non-empty if a team member is not a valid Pokemon", ->
      server = new BattleServer()
      invalidPokemon = {}
      server.validateTeam([ invalidPokemon ]).should.not.be.empty

    it "returns non-empty if a team member has a fake species name", ->
      server = new BattleServer()
      invalidPokemon = {name: "NOTREALMON"}
      server.validateTeam([ invalidPokemon ]).should.not.be.empty

    it "returns non-empty if a team member has no moveset", ->
      server = new BattleServer()
      pokemon = Factory("Hitmonchan", moves: null)
      server.validateTeam([ pokemon ]).should.not.be.empty

    it "returns non-empty if a team member has an empty moveset", ->
      server = new BattleServer()
      pokemon = Factory("Hitmonchan", moves: [])
      server.validateTeam([ pokemon ]).should.not.be.empty

    it "returns non-empty if a team member has a bogus moveset", ->
      server = new BattleServer()
      pokemon = Factory("Hitmonchan", moves: true)
      server.validateTeam([ pokemon ]).should.not.be.empty

    it "returns non-empty if a team member has an illegal moveset", ->
      server = new BattleServer()
      pokemon = Factory("Raichu", moves: [ "Volt Tackle", "Encore" ])
      server.validateTeam([ pokemon ], 'bw').should.not.be.empty

    # TODO: 4 is a magic constant
    it "returns non-empty if a pokemon has more than 4 moves", ->
      server = new BattleServer()
      pokemon = Factory "Hitmonchan",
        moves:  [
                  "Ice Punch"
                  "Fire Punch"
                  "Close Combat"
                  "Mach Punch"
                  "Rapid Spin"
                ]
      server.validateTeam([ pokemon ]).should.not.be.empty

    it "returns non-empty if a pokemon has a move it can't learn", ->
      server = new BattleServer()
      pokemon = Factory("Magikarp", moves: [ "Fissure" ])
      server.validateTeam([ pokemon ]).should.not.be.empty

    it "returns non-empty if a pokemon has a fake move", ->
      server = new BattleServer()
      pokemon = Factory("Magikarp", moves: [ "Splash", "Armageddon" ])
      server.validateTeam([ pokemon ]).should.not.be.empty

    it "returns non-empty if a pokemon has an ability it can't have", ->
      server = new BattleServer()
      pokemon = Factory("Magikarp", ability: "Wonder Guard")
      server.validateTeam([ pokemon ]).should.not.be.empty

    it "returns non-empty if a pokemon has a bogus ability", ->
      server = new BattleServer()
      pokemon = Factory("Magikarp", ability: "Being Batman")
      server.validateTeam([ pokemon ]).should.not.be.empty

    it "returns empty if a pokemon has a hidden ability", ->
      server = new BattleServer()
      pokemon = Factory("Cloyster", ability: "Overcoat")
      server.validateTeam([ pokemon ]).should.be.empty

    it "returns non-empty if a pokemon has a level below 1", ->
      server = new BattleServer()
      pokemon = Factory("Magikarp", level: 0)
      server.validateTeam([ pokemon ]).should.not.be.empty

    it "returns non-empty if a pokemon has a bogus level", ->
      server = new BattleServer()
      pokemon = Factory("Magikarp", level: "hi")
      server.validateTeam([ pokemon ]).should.not.be.empty

    # TODO: 100 is a magic constant
    it "returns non-empty if a pokemon has a level over 100", ->
      server = new BattleServer()
      pokemon = Factory("Magikarp", level: 101)
      server.validateTeam([ pokemon ]).should.not.be.empty

    it "returns non-empty if a pokemon has an iv below 0", ->
      server = new BattleServer()
      pokemon = Factory("Magikarp", ivs: { hp: -1 })
      server.validateTeam([ pokemon ]).should.not.be.empty

    it "returns non-empty if a pokemon has an iv above 31", ->
      server = new BattleServer()
      pokemon = Factory("Magikarp", ivs: { hp: 32 })
      server.validateTeam([ pokemon ]).should.not.be.empty

    it "returns non-empty if a pokemon has bogus ivs", ->
      server = new BattleServer()
      pokemon = Factory("Magikarp", ivs: true)
      server.validateTeam([ pokemon ]).should.not.be.empty

    it "returns non-empty if a pokemon has an ev below 0", ->
      server = new BattleServer()
      pokemon = Factory("Magikarp", evs: { hp: -1 })
      server.validateTeam([ pokemon ]).should.not.be.empty

    it "returns non-empty if a pokemon has an ev above 255", ->
      server = new BattleServer()
      pokemon = Factory("Magikarp", evs: { hp: 256 })
      server.validateTeam([ pokemon ]).should.not.be.empty

    it "returns non-empty if a pokemon has bogus evs", ->
      server = new BattleServer()
      pokemon = Factory("Magikarp", evs: true)
      server.validateTeam([ pokemon ]).should.not.be.empty

    it "returns non-empty if a pokemon has an invalid gender", ->
      server = new BattleServer()
      pokemon = Factory("Metagross", gender: "Alien")
      server.validateTeam([ pokemon ]).should.not.be.empty

    it "returns non-empty if a pokemon has a gender it can't have", ->
      server = new BattleServer()
      metagross = Factory("Metagross", gender: "F")
      blissey = Factory("Blissey", gender: "M")
      gallade = Factory("Gallade", gender: "F")
      server.validateTeam([ metagross ]).should.not.be.empty
      server.validateTeam([ blissey ]).should.not.be.empty
      server.validateTeam([ gallade ]).should.not.be.empty

    it "returns non-empty if a pokemon has a bogus forme", ->
      server = new BattleServer()
      blissey = Factory("Blissey", forme: "Super Ultra Mega Blissey")
      server.validateTeam([ blissey ]).should.not.be.empty

    it "returns non-empty if a pokemon cannot have its forme"

  describe "users", ->
    it "are recorded to be playing in which battles", ->
      server = new BattleServer()
      [ user1, user2, user3 ] = [ "a", "b", "c" ]
      server.queuePlayer(user1, [ Factory("Magikarp") ])
      server.queuePlayer(user2, [ Factory("Magikarp") ])
      server.queuePlayer(user3, [ Factory("Magikarp") ])
      server.beginBattles (err, battleIds) ->
        server.getUserBattles(user1).should.eql(battleIds)
        server.getUserBattles(user2).should.eql(battleIds)
        server.getUserBattles(user3).should.be.empty

    it "no longer records battles once they end", ->
      server = new BattleServer()
      [ user1, user2, user3 ] = [ "a", "b", "c" ]
      server.queuePlayer(user1, [Factory("Blissey"), Factory("Skarmory")])
      server.queuePlayer(user2, [Factory("Blissey")])
      server.queuePlayer(user3, [Factory("Blissey")])
      server.beginBattles (err, battleIds) ->
        for battleId in battleIds
          battle = server.findBattle(battleId)
          battle.endBattle()
        server.getUserBattles(user1).should.be.empty
        server.getUserBattles(user2).should.be.empty
        server.getUserBattles(user3).should.be.empty

  describe "a battle", ->
    beforeEach (done) ->
      @server = new BattleServer()
      [ @user1, @user2, @user3 ] = [ "a", "b", "c" ]
      @server.queuePlayer(@user1, [ Factory("Magikarp") ])
      @server.queuePlayer(@user2, [ Factory("Magikarp"), Factory("Magikarp") ])
      @server.queuePlayer(@user3, [ Factory("Magikarp") ])
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
