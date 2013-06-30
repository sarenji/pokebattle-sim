import string
import requests
import json

output_path = '../../data/bw/data_pokemon.json'

formes_url = 'https://raw.github.com/veekun/pokedex/master/pokedex/data/csv/pokemon_forms.csv'
species_url = 'https://raw.github.com/veekun/pokedex/master/pokedex/data/csv/pokemon_species.csv'
stats_url = 'https://raw.github.com/veekun/pokedex/master/pokedex/data/csv/pokemon_stats.csv'
types_url = 'https://raw.github.com/veekun/pokedex/master/pokedex/data/csv/pokemon_types.csv'
type_names_url = 'https://raw.github.com/veekun/pokedex/master/pokedex/data/csv/types.csv'
pokemon_url = 'https://raw.github.com/veekun/pokedex/master/pokedex/data/csv/pokemon.csv'
moves_url = 'https://raw.github.com/veekun/pokedex/master/pokedex/data/csv/pokemon_moves.csv'
move_names_url = 'https://raw.github.com/veekun/pokedex/master/pokedex/data/csv/move_names.csv'

int_to_stat = {
  1: 'hp',
  2: 'attack',
  3: 'defense',
  4: 'specialAttack',
  5: 'specialDefense',
  6: 'speed',
}

class Pokemon:
  def __init__(self, raw_id, pokemon_info, forme_name=None):
    self.name = pokemon_info.species
    self.info = pokemon_info.info
    self.info['id'] = int(raw_id)
    if forme_name:
      self.name = "%s (%s)" % (self.name, forme_name)

class PokemonInfo:
  def __init__(self, species, weight):
    self.info = {'species': species, 'weight': weight}
    self.species = species

  def add_base_stat(self, stat_id, stat):
    stats = self.info.setdefault('stats', {})
    stat_str = int_to_stat[int(stat_id)]
    stats[stat_str] = int(stat)

  def add_type(self, t):
    types = self.info.setdefault('types', [])
    types.append(t)

  def add_move(self, move):
    moves = self.info.setdefault('moves', [])
    if move not in moves:
      moves.append(move)


pokemon = []
species = {} # Maps species_id to species names.
formes = {}  # Maps pokemon stat/type data.

def map_species_names():
  lines = requests.get(species_url).text.splitlines()
  lines.pop(0) # get rid of info

  while len(lines) > 0:
    line = lines.pop(0)
    species_id, name, generation_id, *tail = line.split(',')
    species[species_id] = string.capwords(string.capwords(name), '-')

def create_formes():
  lines = requests.get(pokemon_url).text.splitlines()
  lines.pop(0) # get rid of info

  while len(lines) > 0:
    line = lines.pop(0)
    forme_id, species_id, height, weight, *tail = line.split(',')
    species_name = species[species_id]
    formes[forme_id] = PokemonInfo(species_name, int(weight))

def add_stats():
  # Base Stats
  lines = requests.get(stats_url).text.splitlines()
  lines.pop(0) # get rid of info

  while len(lines) > 0:
    for _ in range(6):
      line = lines.pop(0)
      forme_id, stat_id, base_stat, effort = line.split(',')
      formes[forme_id].add_base_stat(stat_id, base_stat)

def add_types():
  type_dict = {}

  lines = requests.get(type_names_url).text.splitlines()
  lines.pop(0) # get rid of info

  while len(lines) > 0:
    line = lines.pop(0)
    type_id, type_name, generation_id, damage_class = line.split(',')
    type_dict[type_id] = type_name.capitalize()

  # Read types for every Pokemon.
  lines = requests.get(types_url).text.splitlines()
  lines.pop(0) # get rid of info

  types = []
  while len(lines) > 0:
    line = lines.pop(0)
    forme_id, type_id, slot = line.split(',')
    formes[forme_id].add_type(type_dict[type_id])

def add_moves():
  move_dict = {}

  # Populate move_dict
  lines = requests.get(move_names_url).text.splitlines()
  lines.pop(0) # get rid of info

  while len(lines) > 0:
    line = lines.pop(0)
    move_id, language_id, name = line.split(',')
    if language_id == '9':
      move_dict[move_id] = name

  # Add moves to PokemonInfo
  lines = requests.get(moves_url).text.splitlines()
  lines.pop(0) # get rid of info

  while len(lines) > 0:
    line = lines.pop(0)
    forme_id, _, move_id, *tail = line.split(',')
    formes[forme_id].add_move(move_dict[move_id])

def create_pokemon():
  lines = requests.get(formes_url).text.splitlines()
  lines.pop(0) # get rid of info

  while len(lines) > 0:
    line = lines.pop(0)
    raw_id, forme_name, forme_id, *tail = line.split(',')
    pokemon.append(Pokemon(raw_id, formes[forme_id], forme_name))

map_species_names()
create_formes()
add_stats()
add_types()
add_moves()
create_pokemon()

pokemon_json = {p.name:p.info for p in pokemon}

with open(output_path, 'w') as f:
  f.write(json.dumps(pokemon_json, sort_keys=True, indent=4))
