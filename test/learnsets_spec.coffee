learnsets = require('../shared/learnsets')
{GenerationJSON} = require '../server/generations'

# We'll use BW data for tests.
{SpeciesData, FormeData} = require('../server/bw/data')

describe "Learnsets:", ->
  testLearnset = (pokemon, func) ->
    describe pokemon, ->
      beforeEach ->
        @pokemon = {name: pokemon}
        @checkMoveset = learnsets.checkMoveset.bind(
          learnsets, GenerationJSON, SpeciesData, @pokemon)

      func.call(this)

  testLearnset "Tyranitar", ->
    it "can learn level-up moves once that level, in its own generation", ->
      @pokemon.level = 29
      @checkMoveset(3, [ "Thrash" ]).should.be.true

    it "cannot learn level-up moves if the level has not been reached", ->
      @pokemon.level = 28
      @checkMoveset(3, [ "Thrash" ]).should.be.false

    it "can learn machine moves in its own generation", ->
      @pokemon.level = 1
      @checkMoveset(2, [ "Attract" ]).should.be.true

    it "can learn tutor moves in its own generation", ->
      @pokemon.level = 1
      @checkMoveset(4, [ "Spite" ]).should.be.true

    it "can learn tutor moves below its generation", ->
      @pokemon.level = 1
      @checkMoveset(4, [ "Seismic Toss" ]).should.be.true

  testLearnset "Mewtwo", ->
    it "can learn machine moves below its generation", ->
      @checkMoveset(2, [ "Bide" ]).should.be.true

    it "cannot learn machine moves below a cutoff point", ->
      @checkMoveset(3, [ "Bide" ]).should.be.false

  testLearnset "Vaporeon", ->
    it "can learn Take Down indirectly from Eevee", ->
      @checkMoveset(3, [ "Take Down" ]).should.be.true

    it "can learn Wish through cross-breeding", ->
      @checkMoveset(3, [ "Wish" ]).should.be.true

  testLearnset "Smeargle", ->
    it "can learn almost any move", ->
      @checkMoveset(3, [ "Spore" ]).should.be.true

    it "cannot learn Chatter", ->
      @checkMoveset(3, [ "Chatter" ]).should.be.false

    it "cannot learn Struggle", ->
      @checkMoveset(3, [ "Struggle" ]).should.be.false

  for pokemon in [ "Pichu", "Raichu" ]
    testLearnset pokemon, ->
      it "can learn Volt Tackle", ->
        @checkMoveset(3, [ "Volt Tackle" ]).should.be.true

      it "can learn Encore", ->
        @checkMoveset(3, [ "Encore" ]).should.be.true

      it "cannot learn Volt Tackle and Encore", ->
        @checkMoveset(3, [ "Volt Tackle", "Encore" ]).should.be.false

  testLearnset "Rotom", ->
    it "Gen 4: learns Overheat in its heat forme", ->
      @pokemon.forme = "heat"
      @checkMoveset(4, [ "Overheat" ]).should.be.true

    it "Gen 5: learns Overheat in its heat forme", ->
      @pokemon.forme = "heat"
      @checkMoveset(5, [ "Overheat" ]).should.be.true

    it "Gen 4: learns Overheat and a standard move in its heat forme", ->
      @pokemon.forme = "heat"
      @checkMoveset(4, [ "Overheat", "Thunderbolt" ]).should.be.true

    it "Gen 5: learns Overheat and a standard move in its heat forme", ->
      @pokemon.forme = "heat"
      @checkMoveset(5, [ "Overheat", "Thunderbolt" ]).should.be.true

    it "Gen 4: learns Air Slash in its fan forme", ->
      @pokemon.forme = "fan"
      @checkMoveset(4, [ "Air Slash" ]).should.be.true

    it "Gen 5: learns Air Slash in its fan forme", ->
      @pokemon.forme = "fan"
      @checkMoveset(5, [ "Air Slash" ]).should.be.true

    it "Gen 4: learns Blizzard in its frost forme", ->
      @pokemon.forme = "frost"
      @checkMoveset(4, [ "Blizzard" ]).should.be.true

    it "Gen 5: learns Blizzard in its frost forme", ->
      @pokemon.forme = "frost"
      @checkMoveset(5, [ "Blizzard" ]).should.be.true

    it "Gen 4: learns Leaf Storm in its mow forme", ->
      @pokemon.forme = "mow"
      @checkMoveset(4, [ "Leaf Storm" ]).should.be.true

    it "Gen 5: learns Leaf Storm in its mow forme", ->
      @pokemon.forme = "mow"
      @checkMoveset(5, [ "Leaf Storm" ]).should.be.true

    it "Gen 4: learns Hydro Pump in its wash forme", ->
      @pokemon.forme = "wash"
      @checkMoveset(4, [ "Hydro Pump" ]).should.be.true

    it "Gen 5: learns Hydro Pump in its wash forme", ->
      @pokemon.forme = "wash"
      @checkMoveset(5, [ "Hydro Pump" ]).should.be.true

    it "Gen 4: cannot learn Blizzard in its default forme", ->
      @checkMoveset(4, [ "Blizzard" ]).should.be.false

    it "Gen 5: cannot learn Blizzard in its default forme", ->
      @checkMoveset(5, [ "Blizzard" ]).should.be.false

    it "Gen 4: cannot learn Blizzard in its heat forme", ->
      @pokemon.forme = "heat"
      @checkMoveset(4, [ "Blizzard", "Overheat" ]).should.be.false

    it "Gen 5: cannot learn Blizzard in its heat forme", ->
      @pokemon.forme = "heat"
      @checkMoveset(5, [ "Blizzard", "Overheat" ]).should.be.false

    it "Gen 4: must know Blizzard in its frost forme", ->
      @pokemon.forme = "frost"
      @checkMoveset(4, [ "Thunderbolt" ]).should.be.false

    it "Gen 5: doesn't need to know Blizzard in its frost forme", ->
      @pokemon.forme = "frost"
      @checkMoveset(5, [ "Thunderbolt" ]).should.be.true

  testLearnset "Deoxys", ->
    it "learns alternate forme moves due to freely switching formes", ->
      @pokemon.forme = "attack"
      @checkMoveset(4, [ "Spikes" ]).should.be.true

  testLearnset "Shaymin", ->
    it "learns alternate forme moves due to freely switching formes", ->
      @checkMoveset(4, [ "Air Slash" ]).should.be.true

  testLearnset "Mamoswine", ->
    it "cannot know 4 egg moves", ->
      moveset = [ "Bite", "Fissure", "Curse", "Icicle Spear" ]
      @checkMoveset(4, moveset).should.be.false

  testLearnset "Yanmega", ->
    it "cannot know 4 egg moves", ->
      moveset = [ "Faint Attack", "Leech Life", "Whirlwind", "Reversal" ]
      @checkMoveset(4, moveset).should.be.false

  testLearnset "Tangrowth", ->
    it "cannot know 4 egg moves", ->
      moveset = [ "Amnesia", "Endeavor", "Leaf Storm", "Power Swap" ]
      @checkMoveset(4, moveset).should.be.false

  testLearnset "Mr. Mime", ->
    it "cannot know 4 egg moves", ->
      moveset = [ "Charm", "Healing Wish", "Fake Out", "Teeter Dance" ]
      @checkMoveset(4, moveset).should.be.false

  testLearnset "Ambipom", ->
    it "cannot know 4 egg moves", ->
      moveset = [ "Slam", "Covet", "Beat Up", "Pursuit" ]
      @checkMoveset(4, moveset).should.be.false

  testLearnset "Lickilicky", ->
    it "cannot know 4 egg moves", ->
      moveset = [ "Amnesia", "Curse", "Belly Drum", "Magnitude" ]
      @checkMoveset(4, moveset).should.be.false

  testLearnset "Roserade", ->
    xit "cannot learn Spikes and Sleep Powder", ->
      @checkMoveset(4, [ "Spikes", "Sleep Powder" ]).should.be.false

  testLearnset "Celebi", ->
    it "can learn Nasty Plot", ->
      moveset = [ "Nasty Plot" ]
      @checkMoveset(4, moveset).should.be.true

  testLearnset "Banette", ->
    it "can learn an event move but not an egg move", ->
      moveset = [ "Cotton Guard", "Pursuit" ]
      @checkMoveset(4, moveset).should.be.false

  testLearnset "Gothitelle", ->
    it "can inherit event moves from its pre-evos", ->
      moveset = [ "Imprison" ]
      @checkMoveset(5, moveset).should.be.true

  testLearnset "Gengar", ->
    it "learns Sludge Wave from dream world", ->
      moveset = [ "Sludge Wave" ]
      @checkMoveset(6, moveset).should.be.true

  describe "learnableMoves", ->
    it "returns all possible learnable moves for a pokemon", ->
      learnableMoves = learnsets.learnableMoves.bind(learnsets, GenerationJSON, SpeciesData)
      moves = learnableMoves({name: "Deoxys"}, 6)
      moves.should.include("Superpower")

    it "returns event moves", ->
      learnableMoves = learnsets.learnableMoves.bind(learnsets, GenerationJSON, SpeciesData)
      moves = learnableMoves({name: "Genesect"}, 6)
      moves.should.include("Shift Gear")

    it "returns dream world moves", ->
      learnableMoves = learnsets.learnableMoves.bind(learnsets, GenerationJSON, SpeciesData)
      moves = learnableMoves({name: "Gengar"}, 6)
      moves.should.include("Sludge Wave")
