sinon = require 'sinon'
{items, moves} = require('../../data/bw')
{basePowerModifier, attackStatModifier} = require '../../server/modifiers'
{Status} = require '../../server/status'
{Attachment} = require '../../server/attachment'
{Factory} = require '../factory'
should = require 'should'
{_} = require 'underscore'
shared = require '../shared'

@test = ->
  describe "leftovers", ->
    it "heals 1/16 of a pokemon's HP at the end of a turn", ->
      shared.create.call this,
        team1: [Factory('Magikarp', item: 'Leftovers')]
      @team1.at(0).currentHP = 1
      @controller.makeMove(@player1, 'Splash')
      @controller.makeMove(@player2, 'Splash')
      amount = Math.floor(@team1.at(0).stat('hp') / 16)
      @team1.at(0).currentHP.should.equal(1 + amount)

  describe "Black Sludge", ->
    it "heals 1/16 of a poison pokemon's HP at the end of a turn", ->
      shared.create.call this,
        team1: [Factory('Weezing', item: 'Black Sludge')]
      @team1.at(0).currentHP = 1
      @controller.makeMove(@player1, 'Splash')
      @controller.makeMove(@player2, 'Splash')
      amount = Math.floor(@team1.at(0).stat('hp') / 16)
      @team1.at(0).currentHP.should.equal(1 + amount)

    it "damages 1/16 of a non-poison pokemon's HP at the end of a turn", ->
      shared.create.call this,
        team1: [Factory('Magikarp', item: 'Black Sludge')]
      @controller.makeMove(@player1, 'Splash')
      @controller.makeMove(@player2, 'Splash')
      fullHP = @team1.at(0).stat('hp')
      amount = Math.floor(fullHP / 16)
      (fullHP - @team1.at(0).currentHP).should.equal(amount)

  describe "muscle band", ->
    it "increases base power of physical moves by 0x1199", ->
      shared.create.call(this)
      move = moves['tackle']
      modifier = items['Muscle Band'].basePowerModifier(move, @battle, @team1.at(0), @team2.at(0))
      modifier.should.equal 0x1199

      move = moves['shadow-ball']
      modifier = items['Muscle Band'].basePowerModifier(move, @battle, @team1.at(0), @team2.at(0))
      modifier.should.equal 0x1000

  describe "Wise Glasses", ->
    it "increases base power of special moves by 0x1199", ->
      shared.create.call(this)
      move = moves['tackle']
      modifier = items['Wise Glasses'].basePowerModifier(move, @battle, @team1.at(0), @team2.at(0))
      modifier.should.equal 0x1000

      move = moves['shadow-ball']
      modifier = items['Wise Glasses'].basePowerModifier(move, @battle, @team1.at(0), @team2.at(0))
      modifier.should.equal 0x1199

  describe "An Orb item", ->
    it "increases base power of moves matching the user's type by 0x1333", ->
      shared.create.call this,
        team1: [Factory('Giratina (origin)')]
      move = moves['outrage']
      modifier = items['Griseous Orb'].basePowerModifier(move, @battle, @team1.at(0), @team2.at(0))
      modifier.should.equal 0x1333

      move = moves['shadow-ball']
      modifier = items['Griseous Orb'].basePowerModifier(move, @battle, @team1.at(0), @team2.at(0))
      modifier.should.equal 0x1333

      move = moves['tackle']
      modifier = items['Griseous Orb'].basePowerModifier(move, @battle, @team1.at(0), @team2.at(0))
      modifier.should.equal 0x1000

  describe "A type-boosting miscellaneous item", ->
    it "increases base power of certain typed moves by 0x1333", ->
      shared.create.call(this)
      move = moves['outrage']
      modifier = items['Odd Incense'].basePowerModifier(move, @battle, @team1.at(0), @team2.at(0))
      modifier.should.equal 0x1000

      move = moves['psychic']
      modifier = items['Odd Incense'].basePowerModifier(move, @battle, @team1.at(0), @team2.at(0))
      modifier.should.equal 0x1333

  describe "A typed Gem", ->
    it "increases base power of certain typed moves by 0x1800", ->
      shared.create.call(this)
      move = moves['acrobatics']
      modifier = items['Flying Gem'].basePowerModifier(move, @battle, @team1.at(0), @team2.at(0))
      modifier.should.equal 0x1800

      move = moves['psychic']
      modifier = items['Flying Gem'].basePowerModifier(move, @battle, @team1.at(0), @team2.at(0))
      modifier.should.equal 0x1000

    it "is removed after use", ->
      shared.create.call this,
        team1: [Factory('Magikarp', item: 'Flying Gem')]
      @controller.makeMove(@player1, 'Acrobatics')
      @controller.makeMove(@player2, 'Splash')

      should.not.exist @team1.at(0).item

    it "is not removed after use if the move isn't the right type", ->
      shared.create.call this,
        team1: [Factory('Magikarp', item: 'Flying Gem')]
      @controller.makeMove(@player1, 'Tackle')
      @controller.makeMove(@player2, 'Splash')

      should.exist @team1.at(0).item

  describe "A typed plate", ->
    it "has the plate attribute set", ->
      item = items['Draco Plate']
      item.should.have.property('plate')

    it "changes the Arceus type"

  describe "DeepSeaTooth", ->
    it "doubles Clamperl's special attack", ->
      shared.create.call this,
        team1: [Factory('Clamperl', item: 'DeepSeaTooth')]
      modifier = attackStatModifier.run(moves['surf'], @battle, @team1.at(0), @team2.at(0))
      modifier.should.equal 0x2000

    it "doesn't double Clamperl's attack", ->
      shared.create.call this,
        team1: [Factory('Clamperl', item: 'DeepSeaTooth')]
      modifier = attackStatModifier.run(moves['tackle'], @battle, @team1.at(0), @team2.at(0))
      modifier.should.equal 0x1000

    it "doesn't double non-Clamperl special attack", ->
      shared.create.call this,
        team1: [Factory('Magikarp', item: 'DeepSeaTooth')]
      modifier = attackStatModifier.run(moves['surf'], @battle, @team1.at(0), @team2.at(0))
      modifier.should.equal 0x1000

  describe "Rocky Helmet", ->
    it "deals 1/6 of the attacker's total HP on a contact move", ->
      shared.create.call this,
        team2: [Factory('Ferrothorn', item: 'Rocky Helmet')]

      hp = @team1.first().stat('hp')
      currentHP = @team1.first().currentHP = Math.floor(hp * 2 / 3)
      @controller.makeMove(@player1, 'Tackle')
      @controller.makeMove(@player2, 'Splash')

      @team1.first().currentHP.should.equal currentHP - Math.floor(hp / 6)

    it "doesn't deal damage back to attacker if not a contact move", ->
      shared.create.call this,
        team2: [Factory('Ferrothorn', item: 'Rocky Helmet')]

      hp = @team1.first().stat('hp')
      currentHP = @team1.first().currentHP = Math.floor(hp * 2 / 3)
      @controller.makeMove(@player1, 'Earthquake')
      @controller.makeMove(@player2, 'Splash')

      @team1.first().currentHP.should.equal currentHP

    it "stacks with each hit of multi-hit moves like Tail Slap"
    it "doesn't let certain effects activate if attacker faints"

  testBoostOnTypeItem = (itemName, move, stat) ->
    describe itemName, ->
      it "boosts the special attack of the target by 1 if hit by a water move", ->
        shared.create.call this,
          team2: [Factory("Ferrothorn", item: itemName)]
        @controller.makeMove(@player1, move)
        @controller.makeMove(@player2, 'Splash')

        @team2.first().stages[stat].should.equal 1

      it "is one-time use", ->
        shared.create.call this,
          team2: [Factory("Ferrothorn", item: itemName)]
        @controller.makeMove(@player1, move)
        @controller.makeMove(@player2, 'Splash')

        should.not.exist @team2.first().item

      it "does not boost the special attack of the target by 1 if not hit by a water move", ->
        shared.create.call this,
          team2: [Factory("Ferrothorn", item: itemName)]
        @controller.makeMove(@player1, 'Ember')
        @controller.makeMove(@player2, 'Splash')

        @team2.first().stages[stat].should.equal 0

  testBoostOnTypeItem("Absorb Bulb", "Water Gun", "specialAttack")
  testBoostOnTypeItem("Cell Battery", "Thunderbolt", "attack")

  describe "Float Stone", ->
    it "halves the user's weight", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Float Stone")]

      weight = @team1.first().weight
      @team1.first().calculateWeight().should.equal Math.floor(weight / 2)

  describe "Focus Sash", ->
    it "always lets the user survive at 100% HP", ->
      shared.create.call this,
        team2: [Factory("Magikarp", item: "Focus Sash")]

      item = items['Focus Sash']
      damage = item.editDamage(@battle, @team2.first(), moves['ember'], 99999)
      damage.should.equal @team2.first().currentHP - 1

    it "should not activate at <100% HP", ->
      shared.create.call this,
        team2: [Factory("Magikarp", item: "Focus Sash")]

      @team1.first().currentHP--

      item = items['Focus Sash']
      damage = item.editDamage(@battle, @team1.first(), moves['ember'], 99999)
      damage.should.equal 99999

    it "disappears after activation", ->
      shared.create.call this,
        team2: [Factory("Magikarp", item: "Focus Sash")]

      stub = sinon.stub(moves['ember'], 'calculateDamage', -> 9999)

      @controller.makeMove(@player1, 'Ember')
      @controller.makeMove(@player2, 'Splash')

      stub.restore()
      @team2.first().hasItem().should.be.false

  describe "Choice items", ->
    it "locks the user into its first selected move", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Choice Band")]

      @controller.makeMove(@player1, 'Splash')
      @controller.makeMove(@player2, 'Splash')

      requestedMoves = @battle.requests[@player1.id].moves
      requestedMoves.should.eql [ moves['splash'] ]

    it "does not lock the user if it moves after gaining the item", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Choice Band", evs: {speed:4})]

      @controller.makeMove(@player1, 'Trick')
      @controller.makeMove(@player2, 'Splash')

      requestedMoves = @battle.requests[@player2.id].moves
      requestedMoves.should.eql [ moves['splash'], moves['tackle'] ]

    it "does not automatically lock the user when it switches back in", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Choice Band"), Factory("Magikarp")]

      @controller.makeMove(@player1, 'Splash')
      @controller.makeMove(@player2, 'Splash')

      @controller.makeSwitch(@player1, 1)
      @controller.makeMove(@player2, 'Splash')

      requestedMoves = @battle.requests[@player1.id].moves
      requestedMoves.should.eql [ moves['splash'], moves['tackle'] ]

    xit "relocks the pokemon after Magic Room"

  describe "Choice Scarf", ->
    it "increases the speed of the Pokemon by x1.5", ->
      shared.create.call(this)

      speed = @team1.first().stat('speed')
      @team1.first().setItem(@battle, items['Choice Scarf'])
      @team1.first().stat('speed').should.equal Math.floor(speed * 1.5)

  describe "Flame Orb", ->
    it "burns the user at the end of the turn", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Flame Orb")]

      @controller.makeMove(@player1, 'Splash')
      @controller.makeMove(@player2, 'Splash')

      @team1.first().hasStatus(Status.BURN).should.be.true

    it "does not burn the user if it is already statused", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Flame Orb")]

      @team1.first().setStatus(Status.SLEEP)

      @controller.makeMove(@player1, 'Splash')
      @controller.makeMove(@player2, 'Splash')

      @team1.first().hasStatus(Status.BURN).should.be.false

  describe "Toxic Orb", ->
    it "toxics the user at the end of the turn", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Toxic Orb")]

      @controller.makeMove(@player1, 'Splash')
      @controller.makeMove(@player2, 'Splash')

      @team1.first().hasStatus(Status.TOXIC).should.be.true

    it "does not toxic the user if it is already statused", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Toxic Orb")]

      @team1.first().setStatus(Status.SLEEP)

      @controller.makeMove(@player1, 'Splash')
      @controller.makeMove(@player2, 'Splash')

      @team1.first().hasStatus(Status.TOXIC).should.be.false

  describe "Air Balloon", ->
    it "makes the user immune to ground moves", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Air Balloon")]

      move = moves['earthquake']
      type = move.getType(@battle, @team1.first(), @team2.first())
      @team1.first().isImmune(@battle, type).should.be.true

    it "pops if hit by an attacking move", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Air Balloon")]

      @controller.makeMove(@player1, 'Splash')
      @controller.makeMove(@player2, 'Tackle')

      @team1.first().hasItem().should.be.false

    it "does not pop if hit by a non-attacking move", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Air Balloon")]

      @controller.makeMove(@player1, 'Splash')
      @controller.makeMove(@player2, 'Flatter')

      @team1.first().hasItem().should.be.true

    it "no longer makes the pokemon immune when popped", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Air Balloon")]

      @controller.makeMove(@player1, 'Splash')
      @controller.makeMove(@player2, 'Tackle')

      move = moves['earthquake']
      type = move.getType(@battle, @team1.first(), @team2.first())
      @team1.first().isImmune(@battle, type).should.be.false

    it "stops effecting a pokemon if Tricked away", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Air Balloon")]
        team2: [Factory("Magikarp", item: "Leftovers")]

      @controller.makeMove(@player1, 'Splash')
      @controller.makeMove(@player2, 'Trick')

      @team1.first().hasAttachment(Attachment.AirBalloon).should.be.false
      @team2.first().hasAttachment(Attachment.AirBalloon).should.be.true

  describe "White Herb", ->
    it "negates negative status boosts", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "White Herb")]

      @controller.makeMove(@player1, 'Shell Smash')
      @controller.makeMove(@player2, 'Splash')

      @team1.first().stages.should.include {
        attack: 2, defense: 0, speed: 2, specialAttack: 2, specialDefense: 0
      }

  describe "Life Orb", ->
    it "removes 10% from the pokemon's HP when using an attacking move", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Life Orb")]

      @controller.makeMove(@player1, 'Tackle')
      @controller.makeMove(@player2, 'Splash')

      hp = @team1.first().stat('hp')
      (hp - @team1.first().currentHP).should.equal Math.floor(hp / 10)

    it "doesn't remove 10% HP when using a non-attacking move", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Life Orb")]

      @controller.makeMove(@player1, 'Growl')
      @controller.makeMove(@player2, 'Splash')

      @team1.first().currentHP.should.equal @team1.first().stat('hp')

  describe "Salac berry", ->
    it "raises the Pokemon's Speed when HP falls at 25% or less", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Salac Berry")]

      @controller.makeMove(@player1, 'Splash')
      @controller.makeMove(@player2, 'Splash')

      @team1.first().stages.speed.should.equal(0)

      @team1.first().currentHP = Math.floor(@team1.first().currentHP / 4)
      @controller.makeMove(@player1, 'Splash')
      @controller.makeMove(@player2, 'Splash')

      @team1.first().stages.speed.should.equal(1)

    it "is consumed after use", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Salac Berry")]

      @team1.first().currentHP = Math.floor(@team1.first().currentHP / 4)
      @controller.makeMove(@player1, 'Splash')
      @controller.makeMove(@player2, 'Splash')

      @team1.first().hasItem().should.be.false

  describe "Starf berry", ->
    it "sharply raises a random stat when HP falls at 25% or less", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Starf Berry")]

      shared.biasRNG.call(this, "randInt", 'starf berry stat', 1)

      @team1.first().currentHP = Math.floor(@team1.first().currentHP / 4)
      @controller.makeMove(@player1, 'Splash')
      @controller.makeMove(@player2, 'Splash')

      @team1.first().stages.defense.should.equal(2)

    it "is consumed after use", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Salac Berry")]

      @team1.first().currentHP = Math.floor(@team1.first().currentHP / 4)
      @controller.makeMove(@player1, 'Splash')
      @controller.makeMove(@player2, 'Splash')

      @team1.first().hasItem().should.be.false

    it "only raises stats that aren't at +6", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Starf Berry")]

      shared.biasRNG.call(this, "randInt", 'starf berry stat', 1)

      @team1.first().stages.defense = 6
      @team1.first().currentHP = Math.floor(@team1.first().currentHP / 4)
      @controller.makeMove(@player1, 'Splash')
      @controller.makeMove(@player2, 'Splash')

      # Note: This depends on the stats array inside
      # the definition of Starf Berry. Not exactly robust.
      @team1.first().stages.specialAttack.should.equal(2)
      @team1.first().hasItem().should.be.false

    it "doesn't raise any stat if all main stats are at +6", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Starf Berry")]

      shared.biasRNG.call(this, "randInt", 'starf berry stat', 1)

      stats = ["attack", "defense", "specialAttack", "specialDefense", "speed"]
      for stat in stats
        @team1.first().stages[stat] = 6

      @team1.first().currentHP = Math.floor(@team1.first().currentHP / 4)
      @controller.makeMove(@player1, 'Splash')
      @controller.makeMove(@player2, 'Splash')

      hash = {}
      for stat in stats
        hash[stat] = 6
      @team1.first().stages.should.include(hash)
      @team1.first().hasItem().should.be.false

  describe "a flavor healing berry", ->
    it "restores 1/8 of the Pokemon's HP when at 50% HP or under", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Figy Berry")]

      @controller.makeMove(@player1, 'Splash')
      @controller.makeMove(@player2, 'Splash')

      @team1.first().hasItem().should.be.true

      maxHP = @team1.first().stat('hp')
      hp = Math.floor(maxHP / 2)
      @team1.first().currentHP = hp
      @controller.makeMove(@player1, 'Splash')
      @controller.makeMove(@player2, 'Splash')

      @team1.first().currentHP.should.equal(hp + Math.floor(maxHP / 8))

    it "is consumed after use", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Figy Berry")]

      @team1.first().currentHP = Math.floor(@team1.first().stat('hp') / 2)
      @controller.makeMove(@player1, 'Splash')
      @controller.makeMove(@player2, 'Splash')

      @team1.first().hasItem().should.be.false

    it "confuses the owner if its nature decreases a specific stat", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Figy Berry", nature: "Calm")]

      @team1.first().currentHP = Math.floor(@team1.first().stat('hp') / 2)
      @controller.makeMove(@player1, 'Splash')
      @controller.makeMove(@player2, 'Splash')

      @team1.first().hasAttachment(Attachment.Confusion).should.be.true

  describe "a healing berry", ->
    it "restores a variable number of HP when owner is at 50% HP or under", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Sitrus Berry")]

      @controller.makeMove(@player1, 'Splash')
      @controller.makeMove(@player2, 'Splash')

      @team1.first().hasItem().should.be.true

      maxHP = @team1.first().stat('hp')
      hp = Math.floor(maxHP / 2)
      @team1.first().currentHP = hp
      @controller.makeMove(@player1, 'Splash')
      @controller.makeMove(@player2, 'Splash')

      @team1.first().currentHP.should.equal(hp + Math.floor(maxHP / 4))

    it "is consumed after use", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Sitrus Berry")]

      @team1.first().currentHP = Math.floor(@team1.first().stat('hp') / 2)
      @controller.makeMove(@player1, 'Splash')
      @controller.makeMove(@player2, 'Splash')

      @team1.first().hasItem().should.be.false

  describe "a type-resist berry", ->
    it "halves base power of a super-effective move used on the target", ->
      shared.create.call this,
        team2: [Factory("Blaziken", item: "Shuca Berry")]

      move = moves['earthquake']
      mod = basePowerModifier.run(move, @battle, @team1.first(), @team2.first())
      mod.should.equal 0x800

    it "is consumed after use", ->
      shared.create.call this,
        team2: [Factory("Blaziken", item: "Shuca Berry")]

      @controller.makeMove(@player1, 'Earthquake')
      @controller.makeMove(@player2, 'Splash')

      @team2.first().hasItem().should.be.false

    it "is not triggered by non-damaging moves", ->
      shared.create.call this,
        team2: [Factory("Celebi", item: "Occa Berry")]

      @controller.makeMove(@player1, 'Will-O-Wisp')
      @controller.makeMove(@player2, 'Splash')

      @team2.first().hasItem().should.be.true

    it "does not halve if the move is not of the required type", ->
      shared.create.call this,
        team2: [Factory("Blaziken", item: "Shuca Berry")]

      move = moves['surf']
      mod = basePowerModifier.run(move, @battle, @team1.first(), @team2.first())
      mod.should.equal 0x1000

    it "does not halve if the move is not super-effective", ->
      shared.create.call this,
        team2: [Factory("Magikarp", item: "Shuca Berry")]

      move = moves['earthquake']
      mod = basePowerModifier.run(move, @battle, @team1.first(), @team2.first())
      mod.should.equal 0x1000

    it "halves nevertheless, if it's the normal-resist berry", ->
      shared.create.call this,
        team2: [Factory("Magikarp", item: "Chilan Berry")]

      move = moves['double-edge']
      mod = basePowerModifier.run(move, @battle, @team1.first(), @team2.first())
      mod.should.equal 0x800

  describe "a feedback damage berry", ->
    it "damages the attacker by 12.5% if move class matches", ->
      shared.create.call this,
        team2: [Factory("Magikarp", item: "Jaboca Berry")]

      @controller.makeMove(@player1, 'Tackle')
      @controller.makeMove(@player2, 'Splash')

      hp = @team1.first().stat('hp')
      (hp - @team1.first().currentHP).should.equal Math.floor(hp / 8)

    it "is consumed after use", ->
      shared.create.call this,
        team2: [Factory("Magikarp", item: "Jaboca Berry")]

      @controller.makeMove(@player1, 'Tackle')
      @controller.makeMove(@player2, 'Splash')

      @team2.first().hasItem().should.be.false

    it "does not damage the attacker by 12.5% if move class doesn't match", ->
      shared.create.call this,
        team2: [Factory("Magikarp", item: "Rowap Berry")]

      @controller.makeMove(@player1, 'Tackle')
      @controller.makeMove(@player2, 'Splash')

      @team1.first().currentHP.should.equal @team1.first().stat('hp')

    it "does not damage the attacker if defender faints", ->
      shared.create.call this,
        team2: [Factory("Magikarp", item: "Rowap Berry")]

      @team2.first().currentHP = 1
      @controller.makeMove(@player1, 'Tackle')
      @controller.makeMove(@player2, 'Splash')

      @team1.first().currentHP.should.equal @team1.first().stat('hp')

  describe "status cure berries", ->
    it "restores certain statuses", ->
      shared.create.call this,
        team2: [Factory("Magikarp", item: "Cheri Berry")]

      @team2.first().setStatus(Status.PARALYZE)
      @controller.makeMove(@player1, 'Splash')
      @controller.makeMove(@player2, 'Splash')

      @team2.first().hasStatus(Status.PARALYZE).should.be.false

    it "is consumed after use", ->
      shared.create.call this,
        team2: [Factory("Magikarp", item: "Cheri Berry")]

      @team2.first().setStatus(Status.PARALYZE)
      @controller.makeMove(@player1, 'Splash')
      @controller.makeMove(@player2, 'Splash')

      @team2.first().hasItem().should.be.false

    it "restores confusion", ->
      shared.create.call this,
        team2: [Factory("Magikarp", item: "Lum Berry")]

      shared.biasRNG.call(this, "randInt", 'confusion turns', 4)
      @team2.first().attach(Attachment.Confusion, {@battle})
      @controller.makeMove(@player1, 'Splash')
      @controller.makeMove(@player2, 'Splash')

      @team2.first().hasAttachment(Attachment.Confusion).should.be.false

  describe "Enigma Berry", ->
    it "restores 25% of HP after the owner is hit by a super-effective move", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Enigma Berry")]

      hp = @team1.first().stat('hp')
      damage = Math.floor(hp / 2)
      sinon.stub(@team1.first(), "editDamage", -> damage)
      @controller.makeMove(@player1, 'Splash')
      @controller.makeMove(@player2, 'Thunderbolt')

      @team1.first().currentHP.should.equal(hp - damage + Math.floor(hp / 4))

    it "is consumed after use", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Enigma Berry")]

      @controller.makeMove(@player1, 'Splash')
      @controller.makeMove(@player2, 'Thunderbolt')

      @team1.first().hasItem().should.be.false

    it "doesn't restore 25% of HP if move isn't super-effective", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Enigma Berry")]

      hp = @team1.first().stat('hp')
      damage = Math.floor(hp / 2)
      sinon.stub(@team1.first(), "editDamage", -> damage)
      @controller.makeMove(@player1, 'Splash')
      @controller.makeMove(@player2, 'Tackle')

      @team1.first().currentHP.should.equal(hp - damage)

  testSpeciesBoostingItem = (itemName, speciesArray, statsHash) ->
    describe itemName, ->
      for species in speciesArray
        it "should raise the proper stats given that the wielder is #{species}", ->
          shared.create.call this,
            team1: [Factory(species)]

          stats = (stat  for stat of statsHash)
          pokemonStats = (@team1.first().stat(stat)  for stat in stats)

          @team1.first().setItem(@battle, items[itemName])

          for stat, i in stats
            amount = @team1.first().stat(stat)
            amount.should.equal Math.floor(pokemonStats[i] * statsHash[stat])

      it "shouldn't raise the proper stats given the wrong species", ->
          shared.create.call this,
            team1: [Factory("Magikarp")]

          stats = (stat  for stat of statsHash)
          pokemonStats = (@team1.first().stat(stat)  for stat in stats)

          @team1.first().setItem(@battle, items[itemName])

          for stat, i in stats
            amount = @team1.first().stat(stat)
            amount.should.equal(pokemonStats[i])


  testSpeciesBoostingItem("Soul Dew", ["Latios", "Latias"],
    specialAttack: 1.5, specialDefense: 1.5)
  testSpeciesBoostingItem("DeepSeaTooth", ["Clamperl"], specialAttack: 2)
  testSpeciesBoostingItem("DeepSeaScale", ["Clamperl"], specialDefense: 2)
  testSpeciesBoostingItem("Light Ball", ["Pikachu"], attack: 2, specialAttack: 2)
  testSpeciesBoostingItem("Thick Club", ["Cubone", "Marowak"], attack: 2)
  testSpeciesBoostingItem("Metal Powder", ["Ditto"],
    defense: 2, specialDefense: 2)
  testSpeciesBoostingItem("Quick Powder", ["Ditto"], speed: 2)

  describe "Iron Ball", ->
    it "halves the owner's speed", ->
      shared.create.call(this)

      speed = @team1.first().stat('speed')
      @team1.first().setItem(@battle, items["Iron Ball"])
      @team1.first().stat('speed').should.equal Math.floor(speed / 2)

    it "removes the immunity to ground-type moves", ->
      shared.create.call(this, team1: [Factory("Gyarados", item: "Iron Ball")])

      @team1.first().isImmune(@battle, "Ground").should.be.false

  describe "Leppa Berry", ->
    it "restores 10 PP when the user reaches 0 PP", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Leppa Berry")]

      pokemon = @team1.first()
      move = pokemon.moves[0]
      pokemon.setPP(move, 1)

      @controller.makeMove(@player1, move.name)
      @controller.makeMove(@player2, 'Splash')

      pokemon.pp(move).should.equal 10

    it "restores 10 PP to the first move with 0 PP", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Leppa Berry")]

      pokemon = @team1.first()
      for move in pokemon.moves
        pokemon.setPP(move, 0)
      secondMove  = pokemon.moves[1]
      pokemon.setPP(secondMove, 1)

      @controller.makeMove(@player1, secondMove.name)
      @controller.makeMove(@player2, 'Splash')

      pokemon.pp(pokemon.moves[0]).should.equal 10
      pokemon.pp(secondMove).should.equal 0

  it "is consumed after use", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Leppa Berry")]

      pokemon = @team1.first()
      move = pokemon.moves[0]
      pokemon.setPP(move, 1)

      @controller.makeMove(@player1, move.name)
      @controller.makeMove(@player2, 'Splash')

      pokemon.hasItem().should.be.false

  describe "Focus Band", ->
    it "has a 10% chance to survive an attack", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Focus Band")]

      pokemon = @team1.first()
      pokemon.currentHP = 1

      shared.biasRNG.call(this, "randInt", 'focus band', 0)

      @controller.makeMove(@player1, "Splash")
      @controller.makeMove(@player2, "Tackle")

      pokemon.currentHP.should.equal 1

    it "lets the pokemon faint otherwise", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Focus Band")]

      pokemon = @team1.first()
      pokemon.currentHP = 1

      shared.biasRNG.call(this, "randInt", 'focus band', 1)

      @controller.makeMove(@player1, "Splash")
      @controller.makeMove(@player2, "Tackle")

      pokemon.isFainted().should.be.true

  describe "Binding Band", ->
    it "makes trapping moves deal 1/8 damage per turn, not 1/16", ->
      shared.create.call this,
        team1: [Factory("Magikarp", evs: {speed: 4}, item: "Binding Band")]

      @controller.makeMove(@player1, "Fire Spin")
      @controller.makeMove(@player2, "Recover")

      maxHP = @team2.first().stat('hp')
      expected = maxHP - Math.floor(maxHP / 8)
      @team2.first().currentHP.should.equal expected

  describe "Red Card", ->
    it "drags a pokemon out if a damaging move is used", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Red Card")]
        team2: [Factory("Magikarp"), Factory("Abra")]

      target = @team2.at(1)
      @controller.makeMove(@player1, "Splash")
      @controller.makeMove(@player2, "Tackle")

      @team2.first().should.equal target

    it "destroys the Red Card after use", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Red Card")]
        team2: [Factory("Magikarp"), Factory("Abra")]

      @controller.makeMove(@player1, "Splash")
      @controller.makeMove(@player2, "Tackle")

      @team1.first().hasItem().should.be.false

    # TODO: Find out if these are true or not.
    it "does not activate if there is only one Pokemon left"
    it "does not activate on Sheer Force"

    it "does not activate if a non-damaging move is used", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Red Card")]
        team2: [Factory("Magikarp"), Factory("Abra")]

      target = @team2.first()
      @controller.makeMove(@player1, "Splash")
      @controller.makeMove(@player2, "Will-O-Wisp")

      @team1.first().hasItem().should.be.true
      @team2.first().should.equal target

  describe "Shell Bell", ->
    it "restores 1/8 of damage dealt to target", ->
      shared.create.call(this, team1: [Factory("Magikarp", item: "Shell Bell")])

      @team1.first().currentHP = startHP = 1

      @controller.makeMove(@player1, "Outrage")
      @controller.makeMove(@player2, "Splash")

      damage = @team2.first().stat('hp') - @team2.first().currentHP
      @team1.first().currentHP.should.equal(startHP + Math.floor(damage / 8))

  describe "Sticky Barb", ->
    it "damages 1/8 of holder's HP each turn", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Sticky Barb")]

      @controller.makeMove(@player1, "Splash")
      @controller.makeMove(@player2, "Splash")

      hp = @team1.first().stat('hp')
      (hp - @team1.first().currentHP).should.equal Math.floor(hp / 8)

    it "attaches to the attacking pokemon on a contact move", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Sticky Barb")]

      @controller.makeMove(@player1, "Splash")
      @controller.makeMove(@player2, "Tackle")

      @team1.first().hasItem().should.be.false
      @team2.first().hasItem("Sticky Barb").should.be.true

    it "does not attach to the attacking pokemon on non-contact moves", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Sticky Barb")]

      @controller.makeMove(@player1, "Splash")
      @controller.makeMove(@player2, "Aura Sphere")

      @team1.first().hasItem("Sticky Barb").should.be.true
      @team2.first().hasItem().should.be.false

    it "does not attach if the attacker has an item", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Sticky Barb")]
        team2: [Factory("Magikarp", item: "Leftovers")]

      @controller.makeMove(@player1, "Splash")
      @controller.makeMove(@player2, "Tackle")

      @team1.first().hasItem("Sticky Barb").should.be.true
      @team2.first().hasItem("Leftovers").should.be.true

  describe "Destiny Knot", ->
    it "infatuates the enemy as well if the holder becomes attracted", ->
      shared.create.call this,
        team1: [Factory("Magikarp", gender: "F", item: "Destiny Knot")]
        team2: [Factory("Magikarp", gender: "M")]

      @controller.makeMove(@player1, "Splash")
      @controller.makeMove(@player2, "Attract")

      @team1.first().hasAttachment(Attachment.Attract).should.be.true
      @team2.first().hasAttachment(Attachment.Attract).should.be.true

    it "is one-time use", ->
      shared.create.call this,
        team1: [Factory("Magikarp", gender: "F", item: "Destiny Knot")]
        team2: [Factory("Magikarp", gender: "M")]

      @controller.makeMove(@player1, "Splash")
      @controller.makeMove(@player2, "Attract")

      @team1.first().hasItem().should.be.false

    it "what happens if both pokemon have Destiny Knot?"
    it "what happens if the target is already attracted?"

  describe "Custap Berry", ->
    it "bumps the holder to the front of its priority bracket", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Custap Berry")]
        team2: [Factory("Magikarp", evs: {speed: 4})]

      @team1.first().currentHP = 1
      @team2.first().currentHP = 1

      @battle.recordMove(@id1, moves["tackle"])
      @battle.recordMove(@id2, moves["tackle"])
      @battle.determineTurnOrder()
      pokemon = @battle.priorityQueue.map((o) -> o.pokemon)
      pokemon.should.eql [ @team1.first(), @team2.first() ]

    it "is one-time use", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Custap Berry")]
        team2: [Factory("Magikarp", evs: {speed: 4})]

      @team1.first().currentHP = 1

      @controller.makeMove(@player1, "Splash")
      @controller.makeMove(@player2, "Splash")

      @team1.first().hasItem().should.be.false

    it "does not activate at 26% HP", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Custap Berry")]
        team2: [Factory("Magikarp", evs: {speed: 4})]

      @team1.first().currentHP = Math.floor(@team1.first().currentHP / 4) + 1

      @battle.recordMove(@id1, moves["tackle"])
      @battle.recordMove(@id2, moves["tackle"])
      @battle.determineTurnOrder()
      pokemon = @battle.priorityQueue.map((o) -> o.pokemon)
      pokemon.should.eql [ @team2.first(), @team1.first() ]
      @team1.first().hasItem().should.be.true

    it "activates at 50% HP if the Pokemon has Gluttony"
    it "is not activated by Pursuit on a switching Pokemon"

  describe 'Lansat Berry', ->
    it "gives the owner a Focus Energy attachment", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Lansat Berry")]

      @team1.first().currentHP = Math.floor(@team1.first().currentHP / 4)

      @controller.makeMove(@player1, "Splash")
      @controller.makeMove(@player2, "Splash")

      @team1.first().hasAttachment(Attachment.FocusEnergy).should.be.true

  describe "Micle Berry", ->
    it "gives the owner a 1.2x accuracy boost on their next move", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Micle Berry")]

      @team1.first().currentHP = Math.floor(@team1.first().currentHP / 4)

      @controller.makeMove(@player1, "Tackle")
      @controller.makeMove(@player2, "Splash")

      @team1.first().hasAttachment(Attachment.MicleBerry).should.be.true
      moves['tackle'].chanceToHit(@battle, @team1.first(), @team2.first())
        .should.equal Math.floor(moves['tackle'].accuracy * 1.2)

    it "goes away after their next move", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Micle Berry")]

      @team1.first().currentHP = Math.floor(@team1.first().currentHP / 4)

      @controller.makeMove(@player1, "Tackle")
      @controller.makeMove(@player2, "Splash")

      @controller.makeMove(@player1, "Splash")
      @controller.makeMove(@player2, "Splash")

      @team1.first().hasAttachment(Attachment.MicleBerry).should.be.false

  testEvasionItem = (itemName, ratio=0.9) ->
    describe itemName, ->
      it "gives the owner a #{ratio}x accuracy reduction", ->
        shared.create.call this,
          team2: [Factory("Magikarp", item: itemName)]

        @controller.makeMove(@player1, "Tackle")
        @controller.makeMove(@player2, "Splash")

        moves['tackle'].chanceToHit(@battle, @team1.first(), @team2.first())
          .should.equal Math.floor(moves['tackle'].accuracy * ratio)

      it "no longer reduces accuracy if item is knocked off", ->
        shared.create.call this,
          team2: [Factory("Magikarp", item: itemName)]

        @team2.first().removeItem()

        @controller.makeMove(@player1, "Tackle")
        @controller.makeMove(@player2, "Splash")

        moves['tackle'].chanceToHit(@battle, @team1.first(), @team2.first())
          .should.equal Math.floor(moves['tackle'].accuracy)

  testEvasionItem "BrightPowder"
  testEvasionItem "Lax Incense"

  testDelayItem = (itemName) ->
    describe itemName, ->
      it "delays the user to be last in its priority bracket", ->
        shared.create.call this,
          team1: [Factory("Magikarp", item: itemName, evs: {speed: 4})]
          team2: [Factory("Magikarp")]

        @battle.recordMove(@id1, moves["tackle"])
        @battle.recordMove(@id2, moves["tackle"])
        @battle.determineTurnOrder()
        pokemon = @battle.priorityQueue.map((o) -> o.pokemon)
        pokemon.should.eql [ @team2.first(), @team1.first() ]

  testDelayItem 'Full Incense'
  testDelayItem 'Lagging Tail'

  describe "Macho Brace", ->
    it "halves the owner's speed", ->
      shared.create.call(this)

      speed = @team1.first().stat('speed')
      @team1.first().setItem(@battle, items["Macho Brace"])
      @team1.first().stat('speed').should.equal Math.floor(speed / 2)

  describe "Eject Button", ->
    it "requests a switch immediately after being damaged", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Eject Button"), Factory("Abra")]
        team2: [Factory("Magikarp")]

      bench = @team1.getAliveBenchedPokemon()
      @battle.recordMove(@id1, moves["splash"])
      @battle.recordMove(@id2, moves["tackle"])
      @battle.performMove(@id2, moves["tackle"])

      @battle.requests.should.have.property @id1
      @battle.requests[@id1].should.have.property "switches"
      @battle.requests[@id1].switches.should.eql bench

    it "destroys the Eject Button after use", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Eject Button"), Factory("Abra")]
        team2: [Factory("Magikarp")]

      @controller.makeMove(@player1, "Splash")
      @controller.makeMove(@player2, "Tackle")

      @team1.first().hasItem().should.be.false

    # TODO: Eject Button will force the owner out, and prevent
    # the attacker from switching.
    it "prevents self-switching moves from switching"

    # TODO: Find out if these are true or not.
    it "does not activate if there is only one Pokemon left"
    it "does not activate on Sheer Force"

    it "does not activate if a non-damaging move is used", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Eject Button"), Factory("Abra")]
        team2: [Factory("Magikarp")]

      @battle.recordMove(@id1, moves["splash"])
      @battle.recordMove(@id2, moves["will-o-wisp"])
      @battle.performMove(@id2, moves["will-o-wisp"])

      @team1.first().hasItem().should.be.true
      @battle.requests.should.not.have.property @id1

  describe "Mental Herb", ->
    for effectName in ['Attract','Taunt','Encore','Torment','Disable']
      it "removes the effect of #{effectName} on Pokemon#update", ->
        shared.create.call this,
          team1: [Factory("Magikarp", item: "Mental Herb")]

        pokemon = @team1.first()
        attachment = Attachment[effectName]
        pokemon.hasAttachment(attachment).should.be.false
        pokemon.attach(attachment, turns: 2)
        pokemon.hasAttachment(attachment).should.be.true

        pokemon.update(@battle)

        pokemon.hasAttachment(attachment).should.be.false

    it "disappears after use", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Mental Herb")]

      pokemon = @team1.first()
      pokemon.attach(Attachment.Attract)
      pokemon.update(@battle)

      pokemon.hasItem().should.be.false

    it "gets rid of the first highest priority effect", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Mental Herb")]

      pokemon = @team1.first()
      pokemon.attach(Attachment.Attract)
      pokemon.attach(Attachment.Torment)
      pokemon.update(@battle)

      pokemon.hasAttachment(Attachment.Attract).should.be.false
      pokemon.hasAttachment(Attachment.Torment).should.be.true

  describe "Quick Claw", ->
    it "has a 20% chance to bump the owner's priority", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Quick Claw")]
        team2: [Factory("Magikarp", evs: {speed: 4})]

      shared.biasRNG.call(this, "next", 'quick claw', .1)
      @battle.recordMove(@id1, moves["tackle"])
      @battle.recordMove(@id2, moves["tackle"])
      @battle.determineTurnOrder()
      pokemon = @battle.priorityQueue.map((o) -> o.pokemon)
      pokemon.should.eql [ @team1.first(), @team2.first() ]

    it "has a 80% chance to do nothing", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Quick Claw")]
        team2: [Factory("Magikarp", evs: {speed: 4})]

      shared.biasRNG.call(this, "next", 'quick claw', .2)
      @battle.recordMove(@id1, moves["tackle"])
      @battle.recordMove(@id2, moves["tackle"])
      @battle.determineTurnOrder()
      pokemon = @battle.priorityQueue.map((o) -> o.pokemon)
      pokemon.should.eql [ @team2.first(), @team1.first() ]

  testFlinchItem = (itemName) ->
    describe itemName, ->
      it "has a 10% chance to flinch a Pokemon", ->
        shared.create.call this,
          team1: [Factory("Magikarp", item: itemName)]

        shared.biasRNG.call(this, "next", 'flinch item chance', 0)
        @battle.performMove(@id1, moves["tackle"])
        @team2.first().hasAttachment(Attachment.Flinch).should.be.true

      it "has a 90% chance to do nothing", ->
        shared.create.call this,
          team1: [Factory("Magikarp", item: itemName)]

        shared.biasRNG.call(this, "next", 'flinch item chance', 0.1)
        @battle.performMove(@id1, moves["tackle"])
        @team2.first().hasAttachment(Attachment.Flinch).should.be.false

      it "can't flinch if the move used can already flinch", ->
        shared.create.call this,
          team1: [Factory("Magikarp", item: itemName)]

        shared.biasRNG.call(this, "next", 'flinch item chance', 0)
        shared.biasRNG.call(this, "next", 'secondary effect', 1)
        @battle.performMove(@id1, moves["headbutt"])
        @team2.first().hasAttachment(Attachment.Flinch).should.be.false

      it "can't flinch if the move is non-damaging", ->
        shared.create.call this,
          team1: [Factory("Magikarp", item: itemName)]

        shared.biasRNG.call(this, "next", 'flinch item chance', 0)
        @battle.performMove(@id1, moves["glare"])
        @team2.first().hasAttachment(Attachment.Flinch).should.be.false

  testFlinchItem "King's Rock"
  testFlinchItem "Razor Fang"

  describe "Zoom Lens", ->
    it "multiplies accuracy by 120% if target is moving after", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Zoom Lens", evs: {speed: 4})]
        team2: [Factory("Magikarp")]

      @battle.recordMove(@id1, moves['tackle'])
      @battle.recordMove(@id2, moves['tackle'])

      moves['tackle'].chanceToHit(@battle, @team1.first(), @team2.first())
        .should.equal Math.floor(moves['tackle'].accuracy * 1.2)

    it "doesn't change accuracy if target has already moved", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Zoom Lens")]
        team2: [Factory("Magikarp", evs: {speed: 4})]

      @battle.recordMove(@id1, moves['tackle'])
      @battle.recordMove(@id2, moves['tackle'])
      # Remove tackle from actions to execute
      @battle.popAction(@id2)

      moves['tackle'].chanceToHit(@battle, @team1.first(), @team2.first())
        .should.equal Math.floor(moves['tackle'].accuracy)

  describe "Wide Lens", ->
    it "boosts accuracy by 110%", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Wide Lens")]

      moves['tackle'].chanceToHit(@battle, @team1.first(), @team2.first())
        .should.equal Math.floor(moves['tackle'].accuracy * 1.1)
