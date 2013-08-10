hpTypes = [
  'Fighting', 'Flying', 'Poison', 'Ground', 'Rock', 'Bug', 'Ghost',
  'Steel', 'Fire', 'Water', 'Grass', 'Electric', 'Psychic', 'Ice',
  'Dragon', 'Dark'
]

self = (if module? then module.exports else window.hiddenPower = {})

self.BW ?= {}

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
  hpTypes[Math.floor(value * 15 / 63)]
