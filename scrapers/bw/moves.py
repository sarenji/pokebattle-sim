import requests
import json
import collections

output_path = '../../data/bw/data_moves.json'
moves = {}
types = {}
damage_types = {}
target_types = {}
move_meta = {}

moves_url = 'https://raw.github.com/veekun/pokedex/master/pokedex/data/csv/moves.csv'
type_names_url = 'https://raw.github.com/veekun/pokedex/master/pokedex/data/csv/types.csv'
damage_types_url = 'https://raw.github.com/veekun/pokedex/master/pokedex/data/csv/move_damage_classes.csv'
meta_url = 'https://raw.github.com/veekun/pokedex/master/pokedex/data/csv/move_meta.csv'
targets_url = 'https://raw.github.com/veekun/pokedex/master/pokedex/data/csv/move_targets.csv'

Move = collections.namedtuple('Move', ["id", "identifier", "generation_id", 
  "type_id", "power", "pp", "accuracy", "priority", "target_id", 
  "damage_class_id", "effect_id", "effect_chance", "contest_type_id", 
  "contest_effect_id", "super_contest_effect_id"])

Meta = collections.namedtuple('Meta', ['move_id', 'meta_category_id',
  'meta_ailment_id', 'min_hits', 'max_hits', 'min_turns', 'max_turns',
  'recoil', 'healing', 'crit_rate', 'ailment_chance', 'flinch_chance', 
  'stat_chance'])

# Parse damage types
lines = requests.get(damage_types_url).text.splitlines()
lines.pop(0) # get rid of info

while len(lines) > 0:
  line = lines.pop(0)
  damage_type_id, identifier = line.split(',')
  damage_types[damage_type_id] = identifier


# Parse target types
lines = requests.get(targets_url).text.splitlines()
lines.pop(0) # get rid of info

while len(lines) > 0:
  line = lines.pop(0)
  target_id, identifier = line.split(',')
  target_types[target_id] = identifier


# Parse types
lines = requests.get(type_names_url).text.splitlines()
lines.pop(0) # get rid of info

while len(lines) > 0:
  line = lines.pop(0)
  type_id, type_name, generation_id, damage_class = line.split(',')
  types[type_id] = type_name.capitalize()


# Parse meta info
lines = requests.get(meta_url).text.splitlines()
lines.pop(0) # get rid of info

while len(lines) > 0:
    line = lines.pop(0)
    meta = Meta(*line.split(','))
    move_meta[meta.move_id] = meta


# Parse moves
lines = requests.get(moves_url).text.splitlines()
lines.pop(0) # get rid of info

while len(lines) > 0:
  line = lines.pop(0)
  move = Move(*line.split(','))

  # moves after 10000 are shadow moves 
  if int(move.id) > 10000: continue
  
  moves[move.identifier] = {
    'type'     : types[move.type_id],
    'power'    : int(move.power),
    'pp'       : move.pp and int(move.pp),
    'accuracy' : (move.accuracy and int(move.accuracy)) or 0,
    'priority' : int(move.priority),
    'damage'   : damage_types[move.damage_class_id],
    'target'   : target_types[move.target_id],
  }

  # TODO: Find a simple way to add meta info without default values

  # Veekun crit rates are 0 indexed and 6 means always crits
  # Battletower is 1 indexed and -1 means always crits
  if move_meta[move.id].crit_rate == '6':
    moves[move.identifier]['criticalHitLevel'] = -1
  elif move_meta[move.id].crit_rate != '0':
    criticalHitLevel = int(move_meta[move.id].crit_rate) + 1
    moves[move.identifier]['criticalHitLevel'] = criticalHitLevel
  
with open(output_path, 'w') as f:
  f.write(json.dumps(moves, sort_keys=True, indent=4))

