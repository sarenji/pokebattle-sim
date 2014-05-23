require '../../helpers'

{BattleServer} = require('../../../server/server')
{User} = require('../../../server/user')
pbv = require('../../../shared/pokebattle_values')
{Factory} = require '../../factory'
should = require('should')

describe 'Validations: PBV 500', ->
  it "returns an error if the team is over 500 PBV", ->
    server = new BattleServer()
    format = 'xy500'
    team = [ Factory("Arceus", move: "Recover")
      Factory("Gyarados")
      Factory('Hitmonchan')
      Factory("Celebi")
      Factory("Blissey")
      Factory("Alakazam") ]

    server.validateTeam(team, format).should.not.be.empty

  it "returns an error if the team has under 6 pokemon", ->
    server = new BattleServer()
    format = 'xy500'
    team = [ Factory("Magikarp", moves: [ "Splash" ]) ]

    server.validateTeam(team, format).should.not.be.empty

  it "returns an error if the team has a pokemon that's over 1/3 the cap", ->
    server = new BattleServer()
    format = 'xy500'
    team = [ Factory("Magikarp")
      Factory("Gyarados")
      Factory('Hitmonchan')
      Factory("Celebi")
      Factory("Blissey")
      Factory("Alakazam") ]

    stub = @sandbox.stub(pbv, 'determinePBV', -> 170)

    server.validateTeam(team, format).should.not.be.empty

  it "returns no error if the team is under 500 PBV", ->
    server = new BattleServer()
    format = 'xy500'
    team = [ Factory("Magikarp")
      Factory("Unown", moves: ['Hidden Power'])
      Factory('Hitmonchan', moves: ['Mach Punch'])
      Factory("Abra", moves: ['Psychic'])
      Factory("Froakie", moves: ['Surf'])
      Factory("Raticate", moves: ['Tackle']) ]

    server.validateTeam(team, format).should.be.empty
