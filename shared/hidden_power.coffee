self = (if module? then module.exports else window.HiddenPower ?= {})

self.BW ?= {}

self.BW.types = [
  'Fighting', 'Flying', 'Poison', 'Ground', 'Rock', 'Bug', 'Ghost',
  'Steel', 'Fire', 'Water', 'Grass', 'Electric', 'Psychic', 'Ice',
  'Dragon', 'Dark'
]

self.BW.basePower = (ivs) ->
  base = 0
  base += 1   if ivs['hp'] % 4 > 1
  base += 2   if ivs['attack'] % 4 > 1
  base += 4   if ivs['defense'] % 4 > 1
  base += 8   if ivs['speed'] % 4 > 1
  base += 16  if ivs['specialAttack'] % 4 > 1
  base += 32  if ivs['specialDefense'] % 4 > 1
  Math.floor(base * (40 / 63) + 30)

self.BW.type = (ivs) ->
  value = 0
  value += 1   if ivs['hp'] % 2 == 1
  value += 2   if ivs['attack'] % 2 == 1
  value += 4   if ivs['defense'] % 2 == 1
  value += 8   if ivs['speed'] % 2 == 1
  value += 16  if ivs['specialAttack'] % 2 == 1
  value += 32  if ivs['specialDefense'] % 2 == 1
  self.BW.types[Math.floor(value * 15 / 63)]

self.BW.ivs =
  bug:
    attack: 30
    defense: 30
    specialDefense: 30
  dark: {}
  dragon:
    attack: 30
  electric:
    specialAttack: 30
  fighting:
    defense: 30
    specialAttack: 30
    specialDefense: 30
    speed: 30
  fire:
    attack: 30
    specialAttack: 30
    speed: 30
  flying:
    hp: 30
    attack: 30
    defense: 30
    specialAttack: 30
    specialDefense: 30
  ghost:
    defense: 30
    specialDefense: 30
  grass:
    attack: 30
    specialAttack: 30
  ground:
    specialAttack: 30
    specialDefense: 30
  ice:
    attack: 30
    defense: 30
  poison:
    defense: 30
    specialAttack: 30
    specialDefense: 30
  psychic:
    attack: 30
    speed: 30
  rock:
    defense: 30
    specialDefense: 30
    speed: 30
  steel:
    specialDefense: 30
  water:
    attack: 30
    defense: 30
    specialAttack: 30
