require '../../helpers'

{BattleServer} = require('../../../server/server')
gen = require('../../../server/generations')
{User} = require('../../../server/user')
{Conditions} = require '../../../shared/conditions'
pbv = require('../../../shared/pokebattle_values')
{Factory} = require '../../factory'
should = require('should')

describe 'Validations: PBV 1000', ->
  it "returns an error if the team is over 1000 PBV", ->
    server = new BattleServer()
    generation = 'xy'
    team = [ Factory("Arceus", move: "Recover")
      Factory("Gyarados")
      Factory('Hitmonchan')
      Factory("Celebi")
      Factory("Blissey")
      Factory("Alakazam") ]
    conditions = [ Conditions.PBV_1000 ]

    server.validateTeam(team, generation, conditions).should.not.be.empty

  it "returns an error if the team has under 6 pokemon", ->
    server = new BattleServer()
    generation = 'xy'
    team = [ Factory("Magikarp", moves: [ "Splash" ]) ]
    conditions = [ Conditions.PBV_1000 ]

    server.validateTeam(team, generation, conditions).should.not.be.empty

  it "returns an error if the team has a pokemon that's over 1/3 the cap", ->
    server = new BattleServer()
    generation = 'xy'
    team = [ Factory("Magikarp")
      Factory("Gyarados")
      Factory('Hitmonchan')
      Factory("Celebi")
      Factory("Blissey")
      Factory("Alakazam") ]
    conditions = [ Conditions.PBV_1000 ]

    stub = @sandbox.stub(pbv, 'determinePBV', -> 335)

    server.validateTeam(team, generation, conditions).should.not.be.empty

  it "returns no error if the team is under 1000 PBV", ->
    server = new BattleServer()
    generation = 'xy'
    team = [ Factory("Magikarp")
      Factory("Gyarados")
      Factory('Hitmonchan')
      Factory("Celebi")
      Factory("Blissey")
      Factory("Alakazam") ]
    conditions = [ Conditions.PBV_1000 ]

    server.validateTeam(team, generation, conditions).should.be.empty
