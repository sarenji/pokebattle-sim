require '../../helpers'

{BattleServer} = require('../../../server/server')
gen = require('../../../server/generations')
{User} = require('../../../server/user')
{Conditions} = require '../../../shared/conditions'
{Factory} = require '../../factory'
should = require('should')

describe 'Validations: OHKO Clause', ->
  it "returns an error if a pokemon has an OHKO move", ->
    server = new BattleServer()
    generation = 'xy'
    team = [ Factory("Lapras", moves: [ "Surf", "Sheer Cold" ]) ]
    conditions = [ Conditions.OHKO_CLAUSE ]

    server.validateTeam(team, generation, conditions).should.not.be.empty

  it "returns no error if no pokemon has an evasion move", ->
    server = new BattleServer()
    generation = 'xy'
    team = [
      Factory("Magikarp", moves: [ "Splash" ])
      Factory("Gyarados", moves: [ "Dragon Dance" ])
    ]
    conditions = [ Conditions.OHKO_CLAUSE ]

    server.validateTeam(team, generation, conditions).should.be.empty

  it "ignores invalid moves", ->
    server = new BattleServer()
    generation = 'xy'
    team = [
      Factory("Magikarp", moves: [ "GHOSTFACE KILLAH" ])
      Factory("Gyarados", moves: [ "Dragon Dance" ])
    ]
    conditions = [ Conditions.OHKO_CLAUSE ]

    (-> server.validateTeam(team, generation, conditions)).should.not.throw()
