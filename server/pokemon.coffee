stats = ['hp', 'atk', 'def', 'spAtk', 'spDef', 'spe']
floor = Math.floor

class @Pokemon
  constructor: (attributes = {}) ->
    @species = attributes.species
    @name = attributes.name || 'Missingno'
    @level = attributes.level || 100

    @evs = attributes.evs || {}
    @ivs = attributes.ivs || {}

  iv: (stat) -> @ivs[stat] || 31
  ev: (stat) -> @evs[stat] || 0

  # Gets the stat indexed by key.
  # Ex: pokemon.stat('hp')
  # TODO: Precalculate the stats in the constructor
  stat: (key) ->
    base = 100 # Todo: obtain base stats from the species
    iv = @iv key
    ev_f = floor(@ev(key) / 4)
    if key == 'hp'
      floor (2 * base + iv + ev_f) * (@level / 100) + @level + 10
    else
      @nature_boost = 1
      floor ((2 * base + iv + ev_f) * (@level / 100) + 5) * @nature_boost
