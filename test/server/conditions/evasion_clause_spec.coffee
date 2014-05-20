require '../../helpers'

{BattleServer} = require('../../../server/server')
gen = require('../../../server/generations')
{User} = require('../../../server/user')
{Conditions} = require '../../../shared/conditions'
{Factory} = require '../../factory'
should = require('should')

describe 'Validations: Evasion Clause', ->
  it "returns an error if a pokemon has an evasion move", ->
    server = new BattleServer()
    generation = 'xy'
    team = [ Factory("Umbreon", moves: [ "Double Team" ]) ]
    conditions = [ Conditions.EVASION_CLAUSE ]

    server.validateTeam(team, generation, conditions).should.not.be.empty

  it "returns an error if a pokemon has a banned evasion ability", ->
    server = new BattleServer()
    generation = 'xy'
    team = [ Factory("Smeargle", ability: "Moody", moves: [ "Sketch" ]) ]
    conditions = [ Conditions.EVASION_CLAUSE ]

    server.validateTeam(team, generation, conditions).should.not.be.empty

  it "returns no error if no pokemon has an evasion move", ->
    server = new BattleServer()
    generation = 'xy'
    team = [
      Factory("Magikarp", moves: [ "Splash" ])
      Factory("Gyarados", moves: [ "Dragon Dance" ])
    ]
    conditions = [ Conditions.EVASION_CLAUSE ]

    server.validateTeam(team, generation, conditions).should.be.empty

  it "ignores invalid moves", ->
    server = new BattleServer()
    generation = 'xy'
    team = [
      Factory("Magikarp", moves: [ "GHOSTFACE KILLAH" ])
      Factory("Gyarados", moves: [ "Dragon Dance" ])
    ]
    conditions = [ Conditions.EVASION_CLAUSE ]

    (-> server.validateTeam(team, generation, conditions)).should.not.throw()
