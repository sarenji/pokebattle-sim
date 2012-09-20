import requests
import json
import collections

output_path = '../../data/bw/data_items.json'
items = {}
names = {}
categories = {}
pockets = {}

items_url = 'https://raw.github.com/veekun/pokedex/master/pokedex/data/csv/items.csv'
item_names_url = 'https://raw.github.com/veekun/pokedex/master/pokedex/data/csv/item_names.csv'
categories_url = 'https://raw.github.com/veekun/pokedex/master/pokedex/data/csv/item_categories.csv'
pockets_url = 'https://raw.github.com/veekun/pokedex/master/pokedex/data/csv/item_pockets.csv'

Item = collections.namedtuple('Item', "id,identifier,category_id,cost,fling_power,fling_effect_id")
Name = collections.namedtuple('Name', "item_id,local_language_id,name")
Category = collections.namedtuple('Category', "id,pocket_id,identifier")
Pocket = collections.namedtuple('Pocket', "id,identifier")

# Parse item names
lines = requests.get(item_names_url).text.splitlines()[1:]
for line in lines:
  name = Name(*line.split(','))
  if name.local_language_id == '9': # english
    names[name.item_id] = name.name

# Parse categories
lines = requests.get(categories_url).text.splitlines()[1:]
for line in lines:
  category = Category(*line.split(','))
  categories[category.id] = category.pocket_id

# Parse pockets
lines = requests.get(pockets_url).text.splitlines()[1:]
for line in lines:
  pocket = Pocket(*line.split(','))
  pockets[pocket.id] = pocket.identifier

# Parse items
lines = requests.get(items_url).text.splitlines()[1:]
for line in lines:
  item = Item(*line.split(','))
  name = names[item.id]
  pocket_id = categories[item.category_id]
  fling_power = int(item.fling_power or 0)
  item_type  = pockets[pocket_id]
  items[name] = {
    'type': item_type,
    'flingPower': fling_power,
  }

with open(output_path, 'w') as f:
  dump = json.dumps(items, sort_keys=True, indent=4)
  dump = '\n'.join([ line.rstrip() for line in dump.splitlines() ])
  f.write(dump)

