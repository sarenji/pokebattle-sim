import requests
import json
import collections

output_path = '../../data/bw/data_moves.json'
moves = {}
types = {}

moves_url = 'https://raw.github.com/veekun/pokedex/master/pokedex/data/csv/moves.csv'
type_names_url = 'https://raw.github.com/veekun/pokedex/master/pokedex/data/csv/types.csv'

Move = collections.namedtuple('Move', ["id", "identifier", "generation_id", 
  "type_id", "power", "pp", "accuracy", "priority", "target_id", 
  "damage_class_id", "effect_id", "effect_chance", "contest_type_id", 
  "contest_effect_id", "super_contest_effect_id"])

# Parse types
lines = requests.get(type_names_url).text.splitlines()
lines.pop(0) # get rid of info

while len(lines) > 0:
  line = lines.pop(0)
  type_id, type_name, generation_id, damage_class = line.split(',')
  types[type_id] = type_name.capitalize()

# Parse moves
lines = requests.get(moves_url).text.splitlines()
lines.pop(0) # get rid of info

while len(lines) > 0:
  line = lines.pop(0)
  move = Move(*line.split(','))
  moves[move.identifier] = {
    'type'     : types[move.type_id],
    'power'    : int(move.power),
    'pp'       : move.pp and int(move.pp),
    'accuracy' : move.accuracy and int(move.accuracy),
    'priority' : int(move.priority),
  }
  
with open(output_path, 'w') as f:
  f.write(json.dumps(moves, sort_keys=True, indent=4))

