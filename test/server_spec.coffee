{BattleServer, Player} = require('../').server
{Factory} = require './factory'

require './helpers'

describe 'BattleServer', ->
  it 'can create a new battle', ->
    server = new BattleServer()
    battleId = server.createBattle()
    server.battles.should.have.ownProperty battleId

  it "sends the 'initialize battle' event for each matched player", ->
    players = [{id: 'abc', send: ->}, {id: 'def', send: ->}]
    spies = []
    for player in players
      spy = @sandbox.spy(player, 'send')
      spies.push(spy)

    server = new BattleServer()
    for player in players
      server.queuePlayer(player, [Factory('Hitmonchan')])
    server.beginBattles()

    for spy in spies
      spy.calledWith('initialize battle').should.be.true

  describe "#queuePlayer", ->
    it "queues players", ->
      server = new BattleServer()
      server.queuePlayer(id: "derp", [])
      server.queue.size().should.equal(1)

    it "does not queue null players", ->
      server = new BattleServer()
      server.queuePlayer(null, [])
      server.queue.size().should.equal(0)

    it "does not queue non-logged in players", ->
      server = new BattleServer()
      server.queuePlayer({}, [])
      server.queue.size().should.equal(0)

    it "does not queue players already queued", ->
      server = new BattleServer()
      server.queuePlayer(id: "derp", [])
      server.queuePlayer(id: "derp", [])
      server.queue.size().should.equal(1)

    it "does not queue invalid teams"

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
      server.validateTeam([ pokemon ]).should.not.be.empty

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
      pokemon = Factory("Magikarp", level: true)
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
