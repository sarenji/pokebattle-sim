require './helpers'

should = require 'should'
{PokeBattle} = require '../client/app/js/concerns/team_parsing'

describe "Client", ->
  describe "parsing teams", ->
    beforeEach ->
      @teamString = """
Swampert @ Leftovers
Trait: Torrent
EVs: 252 HP / 252 Def / 4 SDef
Relaxed Nature
- Surf
- Ice Beam
- Earthquake
- Protect

Poop (Blissey) (F) @ Leftovers
Trait: Natural Cure
Shiny: Yes
EVs: 176 HP / 252 Def / 80 SDef
Bold Nature
- Seismic Toss
- Aromatherapy

Skarmory (M)

Tyranitar @ Never-Melt Ice
Ability: Lightning Rod
Level: 1
Happiness: 3
EVs: 252 HP / 80 Def / 176 SDef
- Hidden Power [Grass]
- Extreme Speed

Articuno
IVs: 30 HP / 29 Def
- Hidden Power Fire

Claydol
EVs: 252 SpA / 176 SpD

"""
    it "converts a team to an array readable by this simulator", ->
      team = PokeBattle.parseTeam(@teamString)

      pokemon = team[0]
      pokemon.name.should.equal("Swampert")
      pokemon.should.not.have.property('gender')
      pokemon.item.should.equal("Leftovers")
      pokemon.ability.should.equal("Torrent")
      pokemon.nature.should.equal("Relaxed")
      pokemon.should.not.have.property('level')
      pokemon.should.not.have.property('happiness')
      pokemon.should.not.have.property('shiny')
      pokemon.should.not.have.property('ivs')
      pokemon.evs.should.eql(hp: 252, defense: 252, specialDefense: 4)
      pokemon.moves.should.eql([ "Surf", "Ice Beam", "Earthquake", "Protect"])

      pokemon = team[1]
      pokemon.name.should.equal("Blissey")
      pokemon.gender.should.equal("F")
      pokemon.item.should.equal("Leftovers")
      pokemon.ability.should.equal("Natural Cure")
      pokemon.nature.should.equal("Bold")
      pokemon.should.not.have.property('level')
      pokemon.should.not.have.property('happiness')
      pokemon.shiny.should.be.true
      pokemon.should.not.have.property('ivs')
      pokemon.evs.should.eql(hp: 176, defense: 252, specialDefense: 80)
      pokemon.moves.should.eql(["Seismic Toss", "Aromatherapy"])

      pokemon = team[2]
      pokemon.name.should.equal("Skarmory")
      pokemon.gender.should.equal("M")
      pokemon.should.not.have.property('item')
      pokemon.should.not.have.property('ability')
      pokemon.should.not.have.property('nature')
      pokemon.should.not.have.property('level')
      pokemon.should.not.have.property('happiness')
      pokemon.should.not.have.property('shiny')
      pokemon.should.not.have.property('ivs')
      pokemon.should.not.have.property('evs')
      pokemon.should.not.have.property('moves')

      pokemon = team[3]
      pokemon.name.should.equal("Tyranitar")
      pokemon.should.not.have.property('gender')
      pokemon.should.not.have.property('nature')
      pokemon.level.should.equal(1)
      pokemon.happiness.should.equal(3)
      pokemon.should.not.have.property('shiny')
      pokemon.ivs.should.eql(attack: 30, specialAttack: 30)
      pokemon.evs.should.eql(hp: 252, defense: 80, specialDefense: 176)
      pokemon.moves.should.eql(["Hidden Power", "ExtremeSpeed"])
      pokemon.item.should.eql("NeverMeltIce")
      pokemon.ability.should.eql("Lightningrod")

      pokemon = team[4]
      pokemon.name.should.equal("Articuno")
      pokemon.should.not.have.property('gender')
      pokemon.should.not.have.property('item')
      pokemon.should.not.have.property('ability')
      pokemon.should.not.have.property('nature')
      pokemon.should.not.have.property('level')
      pokemon.should.not.have.property('happiness')
      pokemon.should.not.have.property('shiny')
      # IVs that were explicitly set override Hidden Power!
      pokemon.ivs.should.eql(hp: 30, defense: 29)
      pokemon.should.not.have.property('evs')
      pokemon.moves.should.eql(['Hidden Power'])

      pokemon = team[5]
      pokemon.name.should.equal("Claydol")
      pokemon.evs.should.eql(specialAttack: 252, specialDefense: 176)

  describe "parsing formes", ->
    it "takes into account differing styles of formes", ->
      formes =
        "Thundurus-Therian": ["Thundurus", "therian"]
        "Thundurus-T": ["Thundurus", "therian"]
        "Thundurus": ["Thundurus", null]

        "Landorus-Therian": ["Landorus", "therian"]
        "Landorus-T": ["Landorus", "therian"]
        "Landorus": ["Landorus", null]

        "Tornadus-Therian": ["Tornadus", "therian"]
        "Tornadus-T": ["Tornadus", "therian"]
        "Tornadus": ["Tornadus", null]

        "Shaymin-Sky": ["Shaymin", "sky"]
        "Shaymin-S": ["Shaymin", "sky"]
        "Shaymin": ["Shaymin", null]

        "Giratina-Origin": ["Giratina", "origin"]
        "Giratina-O": ["Giratina", "origin"]
        "Giratina": ["Giratina", null]

        "Arceus-Dark": ["Arceus", null]
        "Arceus": ["Arceus", null]

        "Kyurem-Black": ["Kyurem", "black"]
        "Kyurem-B": ["Kyurem", "black"]
        "Kyurem-White": ["Kyurem", "white"]
        "Kyurem-W": ["Kyurem", "white"]
        "Kyurem": ["Kyurem", null]

        "Rotom-Wash": ["Rotom", "wash"]
        "Rotom-W": ["Rotom", "wash"]
        "Rotom-Fan": ["Rotom", "fan"]
        "Rotom-S": ["Rotom", "fan"]
        "Rotom-Heat": ["Rotom", "heat"]
        "Rotom-H": ["Rotom", "heat"]
        "Rotom-Frost": ["Rotom", "frost"]
        "Rotom-F": ["Rotom", "frost"]
        "Rotom-Mow": ["Rotom", "mow"]
        "Rotom-C": ["Rotom", "mow"]
        "Rotom": ["Rotom", null]

        "Deoxys-Attack": ["Deoxys", "attack"]
        "Deoxys-A": ["Deoxys", "attack"]
        "Deoxys-Defense": ["Deoxys", "defense"]
        "Deoxys-D": ["Deoxys", "defense"]
        "Deoxys-Speed": ["Deoxys", "speed"]
        "Deoxys-S": ["Deoxys", "speed"]
        "Deoxys": ["Deoxys", null]

        "Basculin-Blue-Striped": ["Basculin", "blue-striped"]
        "Basculin-A": ["Basculin", "blue-striped"]
        "Basculin": ["Basculin", null]

        "Keldeo-Resolute": ["Keldeo", "resolute"]
        "Keldeo-R": ["Keldeo", "resolute"]
        "Keldeo": ["Keldeo", null]

        # TODO: "Shellos-East": ["Shellos", "east"]
        "Shellos-East": ["Shellos", "default"]
        "Shellos": ["Shellos", null]

        # TODO: "Gastrodon-East": ["Gastrodon", "east"]
        "Gastrodon-East": ["Gastrodon", "default"]
        "Gastrodon": ["Gastrodon", null]

        "Wormadam-G": ["Wormadam", "sandy"]
        "Wormadam-Sandy": ["Wormadam", "sandy"]
        "Wormadam-S": ["Wormadam", "trash"]
        "Wormadam-Trash": ["Wormadam", "trash"]
        "Wormadam": ["Wormadam", null]

        # TODO: fix these
        "Deerling-Summer": ["Deerling", null]
        "Deerling-Autumn": ["Deerling", null]
        "Deerling-Spring": ["Deerling", null]
        "Deerling": ["Deerling", null]

        "Sawsbuck-Summer": ["Sawsbuck", null]
        "Sawsbuck-Autumn": ["Sawsbuck", null]
        "Sawsbuck-Spring": ["Sawsbuck", null]
        "Sawsbuck": ["Sawsbuck", null]

        "Unown-A": ["Unown", null]
        "Unown": ["Unown", null]

      teamArray = (pokemonName  for pokemonName of formes)
      teamFormes = (forme  for forme in teamArray)

      teamArray.unshift('')
      teamArray.push('')
      teamString = teamArray.join('\n\n')
      team = PokeBattle.parseTeam(teamString)

      for member, i in team
        [species, forme] = formes[teamFormes[i]]
        should.exist(member)
        member.should.have.property('name')
        member.name.should.equal(species)
        if forme
          member.should.have.property('forme')
          member.forme.should.equal(forme)

  describe "exporting teams", ->
    it "exports properly", ->
      team = [
        {
          name: "Pikachu"
          moves: ["Substitute", "Thunderbolt", "Hidden Power", "Grass Knot"]
          item: "Light Ball"
          ability: "Lightningrod"
          gender: "F"
          level: 99
          shiny: true
          happiness: 20
          ivs: { attack: 30, defense: 30 }
          evs: { hp: 4, specialAttack: 252, speed: 252 }
        }
        {
          name: "Kyurem"
          forme: "black"
          item: "Choice Band"
          nature: "Adamant"
          moves: ["Ice Beam", "Fusion Bolt", "Outrage", "Dragon Claw"]
          ability: "Turboblaze"
        }
      ]
      PokeBattle.exportTeam(team).should.equal """

Pikachu (F) @ Light Ball
Ability: Lightningrod
EVs: 4 HP / 252 SAtk / 252 Spe
IVs: 30 Atk / 30 Def
Level: 99
Shiny: Yes
Happiness: 20
- Substitute
- Thunderbolt
- Hidden Power
- Grass Knot

Kyurem-B @ Choice Band
Ability: Turboblaze
Adamant nature
- Ice Beam
- Fusion Bolt
- Outrage
- Dragon Claw


"""
