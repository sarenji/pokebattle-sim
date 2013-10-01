shared = require '../shared'
require '../helpers'

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
    name: "Haunter"
    item: "Leftovers"
    moves: ["Substitute", "Disable", "Shadow Ball", "Focus Blast"]
    ability: "Levitate"
  }
]

describe "BW: Integration:", ->
  describe "a battle", ->
    it "executes fainted replacements at the proper time", ->
      shared.create.call(this, team1: defaultTeam, team2: defaultTeam)
      spy = @sandbox.spy(@battle, 'performReplacements')

      @battle.turn.should.equal(1)
      @sandbox.stub(@battle.getMove("Thunderbolt"), "baseDamage", -> 9999)
      @controller.makeMove(@player1, "Thunderbolt")
      @controller.makeSwitch(@player2, 4)

      @battle.turn.should.equal(1)
      @controller.makeSwitch(@player2, 1)
      @battle.turn.should.equal(2)

      (=>
        @controller.makeMove(@player1, "Thunderbolt")
        @controller.makeSwitch(@player2, 2)
      ).should.not.throw()
      spy.calledOnce.should.be.true
