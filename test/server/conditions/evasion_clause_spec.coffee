require '../../helpers'

{BattleServer} = require('../../../server/server')
{User} = require('../../../server/user')
{Conditions} = require '../../../shared/conditions'
{Factory} = require '../../factory'
should = require('should')

generateTeam = ->
  [ Factory("Magikarp")
    Factory("Gyarados")
    Factory('Hitmonchan')
    Factory("Celebi")
    Factory("Blissey")
    Factory("Alakazam") ]

describe 'Validations: Evasion Clause', ->
  it "returns an error if a pokemon has an evasion move", ->
    server = new BattleServer()
    format = 'xy1000'
    team = generateTeam()
    team[0] = Factory("Umbreon", moves: [ "Double Team" ])
    conditions = [ Conditions.EVASION_CLAUSE ]

    server.validateTeam(team, format, conditions).should.not.be.empty

  it "returns an error if a pokemon has a banned evasion ability", ->
    server = new BattleServer()
    format = 'xy1000'
    team = generateTeam()
    team[0] = Factory("Smeargle", ability: "Moody", moves: [ "Sketch" ])
    conditions = [ Conditions.EVASION_CLAUSE ]

    server.validateTeam(team, format, conditions).should.not.be.empty

  it "returns no error if no pokemon has an evasion move", ->
    server = new BattleServer()
    format = 'xy1000'
    team = generateTeam()
    team[0] = Factory("Magikarp", moves: [ "Splash" ])
    team[1] = Factory("Gyarados", moves: [ "Dragon Dance" ])
    conditions = [ Conditions.EVASION_CLAUSE ]

    server.validateTeam(team, format, conditions).should.be.empty

  it "ignores invalid moves", ->
    server = new BattleServer()
    format = 'xy1000'
    team = generateTeam()
    team[0] = Factory("Magikarp", moves: [ "GHOSTFACE KILLAH" ])
    team[1] = Factory("Gyarados", moves: [ "Dragon Dance" ])
    conditions = [ Conditions.EVASION_CLAUSE ]

    (-> server.validateTeam(team, format, conditions)).should.not.throw()
