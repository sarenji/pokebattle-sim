import requests
import json
import collections

output_path = '../../data/bw/data_moves.json'
moves = {}
types = {}
damage_types = {}
target_types = {}
move_meta = {}
flag_names = {}
flags = {}
ailments = {}
move_names = {}

moves_url = 'https://raw.github.com/veekun/pokedex/master/pokedex/data/csv/moves.csv'
move_names_url = 'https://raw.github.com/veekun/pokedex/master/pokedex/data/csv/move_names.csv'
type_names_url = 'https://raw.github.com/veekun/pokedex/master/pokedex/data/csv/types.csv'
damage_types_url = 'https://raw.github.com/veekun/pokedex/master/pokedex/data/csv/move_damage_classes.csv'
meta_url = 'https://raw.github.com/veekun/pokedex/master/pokedex/data/csv/move_meta.csv'
targets_url = 'https://raw.github.com/veekun/pokedex/master/pokedex/data/csv/move_targets.csv'
flag_names_url = 'https://raw.github.com/veekun/pokedex/master/pokedex/data/csv/move_flags.csv'
flags_url = 'https://raw.github.com/veekun/pokedex/master/pokedex/data/csv/move_flag_map.csv'
ailments_url = 'https://raw.github.com/veekun/pokedex/master/pokedex/data/csv/move_meta_ailments.csv'

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

for line in lines:
  damage_type_id, identifier = line.split(',')
  damage_types[damage_type_id] = identifier


# Parse target types
lines = requests.get(targets_url).text.splitlines()
lines.pop(0) # get rid of info

for line in lines:
  target_id, identifier = line.split(',')
  target_types[target_id] = identifier


# Parse types
lines = requests.get(type_names_url).text.splitlines()
lines.pop(0) # get rid of info

for line in lines:
  type_id, type_name, generation_id, damage_class = line.split(',')
  types[type_id] = type_name.capitalize()


# Parse meta info
lines = requests.get(meta_url).text.splitlines()
lines.pop(0) # get rid of info

for line in lines:
  meta = Meta(*line.split(','))
  move_meta[meta.move_id] = meta


# Parse flag names
lines = requests.get(flag_names_url).text.splitlines()
lines.pop(0) # get rid of info

for line in lines:
  flag_id, flag = line.split(',')
  flag_names[flag_id] = flag


# Parse flags
lines = requests.get(flags_url).text.splitlines()
lines.pop(0) # get rid of info

for line in lines:
  move_id, move_flag_id = line.split(',')
  flag = flag_names[move_flag_id]
  flags.setdefault(move_id, []).append(flag)


# Parse ailments
lines = requests.get(ailments_url).text.splitlines()
lines.pop(0) # get rid of info

for line in lines:
  ailment_id, ailment_name = line.split(',')
  ailments[ailment_id] = ailment_name

# Parse names
lines = requests.get(move_names_url).text.splitlines()
lines.pop(0) # get rid of info

for line in lines:
  move_id, language_id, move_name = line.split(',')
  if language_id != '9': continue
  move_names[move_id] = move_name


# Parse moves
lines = requests.get(moves_url).text.splitlines()
lines.pop(0) # get rid of info

for line in lines:
  data = Move(*line.split(','))

  # moves after 10000 are shadow moves 
  if int(data.id) > 10000: continue
  
  name = move_names[data.id]
  move = moves[name] = {
    'type'     : types[data.type_id],
    'power'    : int(data.power),
    'pp'       : data.pp and int(data.pp),
    'accuracy' : (data.accuracy and int(data.accuracy)) or 0,
    'priority' : int(data.priority),
    'damage'   : damage_types[data.damage_class_id],
    'target'   : target_types[data.target_id],
    'flags'    : flags.get(data.id, [])
  }

  # Add OHKO flag if applicable
  if meta.meta_category_id == 9: move['flags'].append('ohko')

  # TODO: Find a simple way to add meta info without default values
  meta = move_meta[data.id]
  move['recoil'] = int(meta.recoil)
  move['ailmentId'] = ailments[meta.meta_ailment_id]
  move['ailmentChance'] = int(meta.ailment_chance)
  move['flinchChance'] = int(meta.flinch_chance)
  move['minHits'] = int(meta.min_hits or "1")
  move['maxHits'] = int(meta.max_hits or "1")

  # Veekun crit rates are 0 indexed and 6 means always crits
  # Battletower is 1 indexed and -1 means always crits
  if meta.crit_rate == '6':
    move['criticalHitLevel'] = -1
  elif meta.crit_rate != '0':
    criticalHitLevel = int(meta.crit_rate) + 1
    move['criticalHitLevel'] = criticalHitLevel
  
with open(output_path, 'w') as f:
  f.write(json.dumps(moves, sort_keys=True, indent=4))

