require '../helpers'

shared = require '../shared'
{Attachment} = require '../../server/bw/attachment'

defaultTeam = [
  {
    species: "Pikachu"
    moves: ["Substitute", "Thunderbolt", "Hidden Power", "Grass Knot"]
    item: "Light Ball"
    ability: "Lightningrod"
    gender: "F"
  }
  {
    species: "Hitmonchan"
    moves: ["Close Combat", "Mach Punch", "Ice Punch", "ThunderPunch"]
    item: "Life Orb"
    ability: "Iron Fist"
    gender: "M"
  }
  {
    species: "Charizard"
    item: "Choice Specs"
    moves: ["Fire Blast", "Air Slash", "Hidden Power", "Focus Blast"]
    ability: "Blaze"
  }
  {
    species: "Dragonite"
    item: "Leftovers"
    moves: ["Dragon Dance", "Outrage", "Fire Punch", "ExtremeSpeed"]
    ability: "Multiscale"
  }
  {
    species: "Politoed"
    item: "Leftovers"
    moves: ["Scald", "Ice Beam", "Protect", "Toxic"]
    ability: "Drizzle"
  }
  {
    species: "Haunter"
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
      @controller.makeMove(@id1, "Thunderbolt")
      @controller.makeSwitch(@id2, 4)

      @battle.turn.should.equal(1)
      @controller.makeSwitch(@id2, 1)
      @battle.turn.should.equal(2)

      (=>
        @controller.makeMove(@id1, "Thunderbolt")
        @controller.makeSwitch(@id2, 2)
      ).should.not.throw()
      spy.calledOnce.should.be.true

    it "can execute two fainted replacements in a row", ->
      shared.create.call(this, team1: defaultTeam, team2: defaultTeam)
      spy = @sandbox.spy(@battle, 'performReplacements')

      @battle.turn.should.equal(1)

      # Artificially set up conditions
      spy1 = @sandbox.spy(@team2.at(1), "faint")
      spy2 = @sandbox.spy(@team2.at(2), "faint")
      @team2.at(1).currentHP = 1
      @team2.at(2).currentHP = 1
      @team2.attach(Attachment.StealthRock)

      # Now attempt the first replacement.
      @controller.makeSwitch(@id2, 1)
      @controller.makeMove(@id1, "Thunderbolt")

      # Nothing happens except the Pokemon faints.
      @battle.turn.should.equal(1)
      @team2.first().species.should.equal("Hitmonchan")
      @team2.first().isFainted().should.be.true
      @battle.areAllRequestsCompleted().should.be.false

      # Do the second replacement.
      @controller.makeSwitch(@id2, 2)

      # Nothing happens except the Pokemon faints.
      @battle.turn.should.equal(1)
      @team2.first().species.should.equal("Charizard")
      @team2.first().isFainted().should.be.true
      @battle.areAllRequestsCompleted().should.be.false

      # Each pokemon should have called their faint method
      spy1.called.should.be.true
      spy2.called.should.be.true

    it "doesn't trigger weather if a switch-in faints immediately", ->
      shared.create.call(this, team1: defaultTeam, team2: defaultTeam)
      spy = @sandbox.spy(@battle, 'performReplacements')

      @battle.turn.should.equal(1)

      # There should be no weather at the start of the battle.
      @battle.hasWeather().should.be.false

      # Artificially set up conditions
      @team2.at(4).currentHP = 1
      @team2.attach(Attachment.StealthRock)

      # Now attempt the switch.
      @controller.makeSwitch(@id2, 4)
      @controller.makeMove(@id1, "Substitute")

      # Nothing happens except the Pokemon faints.
      @battle.turn.should.equal(1)
      @team2.first().species.should.equal("Politoed")
      @team2.first().isFainted().should.be.true
      @battle.areAllRequestsCompleted().should.be.false

      # There should be no weather.
      @battle.hasWeather().should.be.false

    it "doesn't trigger weather if a replacement faints immediately", ->
      shared.create.call(this, team1: defaultTeam, team2: defaultTeam)

      @battle.turn.should.equal(1)

      # There should be no weather at the start of the battle.
      @battle.hasWeather().should.be.false

      # Artificially set up conditions
      @team2.at(1).currentHP = 1
      @team2.at(4).currentHP = 1
      @team2.attach(Attachment.StealthRock)

      # Now attempt the switches.
      @controller.makeSwitch(@id2, 1)
      @controller.makeMove(@id1, "Substitute")

      # Nothing happens except the Pokemon faints.
      @battle.turn.should.equal(1)
      @team2.first().species.should.equal("Hitmonchan")
      @team2.first().isFainted().should.be.true
      @battle.areAllRequestsCompleted().should.be.false

      # Attempt the replacement
      @controller.makeSwitch(@id2, 4)

      # Nothing happens except the Pokemon faints, again.
      @battle.turn.should.equal(1)
      @team2.first().species.should.equal("Politoed")
      @team2.first().isFainted().should.be.true
      @battle.areAllRequestsCompleted().should.be.false

      # There should be no weather.
      @battle.hasWeather().should.be.false
