import string
import requests
import json

species_output_path = '../../data/bw/data_species.json'
formes_output_path = '../../data/bw/data_formes.json'

formes_url = 'https://raw.github.com/veekun/pokedex/master/pokedex/data/csv/pokemon_forms.csv'
species_url = 'https://raw.github.com/veekun/pokedex/master/pokedex/data/csv/pokemon_species.csv'
species_names_url = 'https://raw.github.com/veekun/pokedex/master/pokedex/data/csv/pokemon_species_names.csv'
egg_groups_url = 'https://raw.github.com/veekun/pokedex/master/pokedex/data/csv/egg_groups.csv'
pokemon_egg_groups_url = 'https://raw.github.com/veekun/pokedex/master/pokedex/data/csv/pokemon_egg_groups.csv'
stats_url = 'https://raw.github.com/veekun/pokedex/master/pokedex/data/csv/pokemon_stats.csv'
types_url = 'https://raw.github.com/veekun/pokedex/master/pokedex/data/csv/pokemon_types.csv'
type_names_url = 'https://raw.github.com/veekun/pokedex/master/pokedex/data/csv/types.csv'
pokemon_url = 'https://raw.github.com/veekun/pokedex/master/pokedex/data/csv/pokemon.csv'
moves_url = 'https://raw.github.com/veekun/pokedex/master/pokedex/data/csv/pokemon_moves.csv'
move_names_url = 'https://raw.github.com/veekun/pokedex/master/pokedex/data/csv/move_names.csv'
ability_names_url = 'https://raw.github.com/veekun/pokedex/master/pokedex/data/csv/ability_names.csv'
abilities_url = 'https://raw.github.com/veekun/pokedex/master/pokedex/data/csv/pokemon_abilities.csv'
move_learn_method_url = 'https://raw.github.com/veekun/pokedex/master/pokedex/data/csv/pokemon_move_methods.csv'

int_to_stat = {
  1: 'hp',
  2: 'attack',
  3: 'defense',
  4: 'specialAttack',
  5: 'specialDefense',
  6: 'speed',
}

version_to_generation = {
  1: 1,   # rb
  2: 1,   # yellow
  3: 2,   # gs
  4: 2,   # crystal
  5: 3,   # rs
  6: 3,   # emerald
  7: 3,   # frlg
  8: 4,   # dp
  9: 4,   # platinum
  10: 4,  # hgss
  11: 5,  # black & white
  12: 3,  # colloseum
  13: 3,  # XD
  14: 5,  # bw-2
}

class Species:
  def __init__(self, species_id, name):
    self.id = int(species_id)
    self.name = name

  def add_gender_ratio(self, gender_ratio):
    self.gender_ratio = int(gender_ratio)

  def add_evolution_lines(self, evolution, prevolution):
    self.evolves_into = evolution
    self.evolved_from = prevolution

  def add_egg_group(self, egg_group):
    self.egg_groups = self.__dict__.setdefault('egg_group', [])
    self.egg_groups.append(egg_group)

  def add_generation(self, generation):
    self.generation = int(generation)

  def to_json(self):
    h = {
      'id'           : self.id,
      'genderRatio'  : self.gender_ratio,
      'eggGroups'    : self.egg_groups,
      'generation'   : self.generation,
    }
    if self.evolves_into is not None:
      h['evolvesInto'] = list(map(lambda s: species[s].name, self.evolves_into))
    if self.evolved_from is not None:
      h['evolvedFrom'] = species[self.evolved_from].name
    return h

class Forme:
  def __init__(self, species):
    self.species = species
    self.hidden_ability = None

  def add_name(self, name):
    if not name:               name = 'default'  # '' or None
    if name == 'ordinary':     name = 'default'  # Keldeo
    if name == 'altered':      name = 'default'  # Giratina
    if name == 'a':            name = 'default'  # Unown
    if name == 'west':         name = 'default'  # Shellos/Gastrodon
    if name == 'blue-striped': name = 'default'  # Basculin
    if name == 'spring':       name = 'default'  # Deerling/Sawsbuck
    if name == 'land':         name = 'default'  # Shaymin
    if name == 'normal':       name = 'default'  # Deoxys/Arceus
    if name == 'standard':     name = 'default'  # Darmanitan
    if name == 'aria':         name = 'default'  # Meloetta
    if name == 'plant':        name = 'default'  # Burmy/Wormadam
    if name == 'overcast':     name = 'default'  # Cherrim
    if name == 'incarnate':    name = 'default'  # The genies
    self.name = name

  def add_base_stat(self, stat_id, stat):
    self.stats = self.__dict__.setdefault('stats', {})
    stat_str = int_to_stat[int(stat_id)]
    self.stats[stat_str] = int(stat)

  def add_type(self, t):
    self.types = self.__dict__.setdefault('types', [])
    self.types.append(t)

  def add_ability(self, ability_name, is_hidden):
    if is_hidden:
      self.hidden_ability = ability_name
    else:
      self.abilities = self.__dict__.setdefault('abilities', [])
      self.abilities.append(ability_name)

  def add_move(self, move, version, method, level):
    version = "generation-%i" % version_to_generation[int(version)]
    learnset = self.__dict__.setdefault('learnset', {})
    version = learnset.setdefault(version, {})
    moves_by_method = version.setdefault(method, {})
    if move not in moves_by_method:
      moves_by_method[move] = int(level)

  def add_weight(self, weight):
    self.weight = int(weight)

  def add_is_battle_only(self, is_battle_only):
    self.is_battle_only = is_battle_only

  def to_json(self):
    h = {
      'stats'         : self.stats,
      'abilities'     : self.abilities,
      'learnset'      : self.learnset,
      'types'         : self.types,
      'weight'        : self.weight,
      'isBattleOnly'  : self.is_battle_only,
    }
    if self.hidden_ability is not None:
      h['hiddenAbility'] = self.hidden_ability
    return h

pokemon = []
species = {} # Maps species_id to species.
species_names = {} # Maps species_id to species names
formes = {}  # Maps pokemon stat/type/etc data.
abilities = {} # Maps ability id to name.
learn_methods = {} # Maps ids to learning method prose
egg_groups = {} # Maps ids to egg group names

def map_species_names():
  lines = requests.get(species_names_url).text.splitlines()
  lines.pop(0) # get rid of info

  while len(lines) > 0:
    line = lines.pop(0)
    species_id, language_id, name, *tail = line.split(',')
    if language_id != '9': continue
    species_names[species_id] = name

def create_species():
  lines = requests.get(species_url).text.splitlines()
  lines.pop(0) # get rid of info

  while len(lines) > 0:
    line = lines.pop(0)
    species_id, name, generation_id, evolves_from_id, evolution_chain_id, _, _, _, gender_rate, *tail = line.split(',')
    specie = Species(species_id, species_names[species_id])
    specie.add_gender_ratio(gender_rate)
    specie.add_generation(generation_id)
    species[species_id] = specie

def map_evolution_line():
  lines = requests.get(species_url).text.splitlines()
  lines.pop(0) # get rid of info

  evolution = {}
  devolution = {}

  while len(lines) > 0:
    line = lines.pop(0)
    species_id, name, generation_id, evolves_from_id, *tail = line.split(',')
    if len(evolves_from_id) == 0: continue
    evolution[species_id] = evolves_from_id
    pre_evos = devolution.setdefault(evolves_from_id, [])
    pre_evos.append(species_id)

  for species_id in species:
    evolved_from = evolution.get(species_id, None)
    evolves_into = devolution.get(species_id, None)

    species[species_id].add_evolution_lines(evolves_into, evolved_from)

def map_abilities():
  lines = requests.get(ability_names_url).text.splitlines()
  lines.pop(0) # get rid of info

  while len(lines) > 0:
    line = lines.pop(0)
    ability_id, local_language_id, name = line.split(',')
    if local_language_id != '9': continue
    abilities[ability_id] = name

def create_formes():
  lines = requests.get(pokemon_url).text.splitlines()
  lines.pop(0) # get rid of info

  while len(lines) > 0:
    line = lines.pop(0)
    forme_id, species_id, height, weight, *tail = line.split(',')
    speci = species[species_id]
    forme = Forme(speci.name)
    forme.add_weight(weight)
    formes[forme_id] = forme

def add_learning_methods():
  lines = requests.get(move_learn_method_url).text.splitlines()
  lines.pop(0) # get rid of info

  while len(lines) > 0:
    line = lines.pop(0)
    method_id, name = line.split(',')
    learn_methods[method_id] = name

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

def add_abilities():
  lines = requests.get(abilities_url).text.splitlines()
  lines.pop(0) # get rid of info

  while len(lines) > 0:
    line = lines.pop(0)
    forme_id, ability_id, is_hidden, slot = line.split(',')
    formes[forme_id].add_ability(abilities[ability_id], bool(int(is_hidden)))

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

  # Add moves to Forme
  lines = requests.get(moves_url).text.splitlines()
  lines.pop(0) # get rid of info

  while len(lines) > 0:
    line = lines.pop(0)
    forme_id, version, move_id, method_id, level, order = line.split(',')
    formes[forme_id].add_move(move_dict[move_id], version, learn_methods[method_id], level)

def map_egg_groups():
  lines = requests.get(egg_groups_url).text.splitlines()
  lines.pop(0) # get rid of info

  while len(lines) > 0:
    line = lines.pop(0)
    egg_group_id, egg_group_name = line.split(',')
    egg_groups[egg_group_id] = egg_group_name

def add_egg_groups():
  lines = requests.get(pokemon_egg_groups_url).text.splitlines()
  lines.pop(0) # get rid of info

  while len(lines) > 0:
    line = lines.pop(0)
    species_id, egg_group_id = line.split(',')
    species[species_id].add_egg_group(egg_groups[egg_group_id])

def add_forme_info():
  lines = requests.get(formes_url).text.splitlines()
  lines.pop(0) # get rid of info

  while len(lines) > 0:
    line = lines.pop(0)
    _, forme_name, forme_id, _, is_default, is_battle_only, *_ = line.split(',')
    is_default = (is_default == '1')
    is_battle_only = (is_battle_only == '1')
    forme = formes[forme_id]
    # is_default seems to indicate the kind of sprite
    # TODO: Add support for other formes like Basculin blue stripe/unowns/etc.
    if is_default:
      forme.add_name(forme_name or 'default')
      forme.add_is_battle_only(is_battle_only)

map_species_names()
create_species()
create_formes()
map_evolution_line()
map_abilities()
map_egg_groups()
add_forme_info()
add_stats()
add_types()
add_abilities()
add_learning_methods()
add_egg_groups()
add_moves()

with open(species_output_path, 'w') as f:
  species_json = {speci.name: speci.to_json()  for speci in species.values()}
  s = json.dumps(species_json, sort_keys=True, indent=4)
  split = s.split('\n')
  split = [ line.rstrip()  for line in split ]
  f.write('\n'.join(split))

with open(formes_output_path, 'w') as f:
  formes_json = {}
  for forme in formes.values():
    h = formes_json.setdefault(forme.species, {})
    h[forme.name] = forme.to_json()
  s = json.dumps(formes_json, sort_keys=True, indent=4)
  split = s.split('\n')
  split = [ line.rstrip()  for line in split ]
  f.write('\n'.join(split))
