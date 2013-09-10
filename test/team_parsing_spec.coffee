{PokeBattle} = require '../client/app/js/concerns/team_parsing'

require 'sugar'
require './helpers'

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

Tyranitar
Level: 1
Happiness: 3
EVs: 252 HP / 80 Def / 176 SDef
- Hidden Power [Grass]

Articuno
IVs: 30 HP / 29 Def
- Hidden Power [Fire]

Thundurus-Therian

Thundurus-T

Shaymin-Sky

Shaymin-S

Giratina-O

Giratina-Origin

Arceus-Dark

Arceus

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
      pokemon.should.not.have.property('item')
      pokemon.should.not.have.property('ability')
      pokemon.should.not.have.property('nature')
      pokemon.level.should.equal(1)
      pokemon.happiness.should.equal(3)
      pokemon.should.not.have.property('shiny')
      pokemon.ivs.should.eql(attack: 30, specialAttack: 30)
      pokemon.evs.should.eql(hp: 252, defense: 80, specialDefense: 176)
      pokemon.moves.should.eql(["Hidden Power"])

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
      pokemon.name.should.equal("Thundurus")
      pokemon.forme.should.equal("therian")

      pokemon = team[6]
      pokemon.name.should.equal("Thundurus")
      pokemon.forme.should.equal("therian")

      pokemon = team[7]
      pokemon.name.should.equal("Shaymin")
      pokemon.forme.should.equal("sky")

      pokemon = team[8]
      pokemon.name.should.equal("Shaymin")
      pokemon.forme.should.equal("sky")

      pokemon = team[9]
      pokemon.name.should.equal("Giratina")
      pokemon.forme.should.equal("origin")

      pokemon = team[10]
      pokemon.name.should.equal("Giratina")
      pokemon.forme.should.equal("origin")

      pokemon = team[11]
      pokemon.name.should.equal("Arceus")
      pokemon.should.not.have.property('forme')

      pokemon = team[12]
      pokemon.name.should.equal("Arceus")
      pokemon.should.not.have.property('forme')
