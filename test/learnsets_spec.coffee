learnsets = require('../shared/learnsets')
{SpeciesData, FormeData} = require('../data/bw')

describe "Learnsets:", ->
  testLearnset = (pokemon, func) ->
    describe pokemon, ->
      beforeEach ->
        @formeName = "default"
        @pokemon = {name: pokemon, forme: @formeName, level: 100}
        @checkMoveset = learnsets.checkMoveset.bind(
          learnsets, SpeciesData, FormeData, @pokemon)

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
    it "learns Overheat in its heat forme", ->
      @pokemon.forme = "heat"
      @checkMoveset(4, [ "Overheat" ]).should.be.true

    it "learns Overheat and a standard move in its heat forme", ->
      @pokemon.forme = "heat"
      @checkMoveset(4, [ "Overheat", "Thunderbolt" ]).should.be.true

    it "learns Air Slash in its fan forme", ->
      @pokemon.forme = "fan"
      @checkMoveset(4, [ "Air Slash" ]).should.be.true

    it "learns Blizzard in its frost forme", ->
      @pokemon.forme = "frost"
      @checkMoveset(4, [ "Blizzard" ]).should.be.true

    it "learns Leaf Storm in its mow forme", ->
      @pokemon.forme = "mow"
      @checkMoveset(4, [ "Leaf Storm" ]).should.be.true

    it "learns Hydro Pump in its wash forme", ->
      @pokemon.forme = "wash"
      @checkMoveset(4, [ "Hydro Pump" ]).should.be.true

    it "cannot learn Blizzard in its heat forme", ->
      @pokemon.forme = "heat"
      @checkMoveset(4, [ "Blizzard" ]).should.be.false

  testLearnset "Roserade", ->
    xit "cannot learn Spikes and Sleep Powder", ->
      @checkMoveset(4, [ "Spikes", "Sleep Powder" ]).should.be.false
