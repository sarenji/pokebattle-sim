coffee = require 'coffee-script'
path = require('path').resolve(__dirname, '../../bw/data/items.coffee')
eval(coffee.compile(require('fs').readFileSync(path, 'utf8'), bare: true))

makeTypeResistBerry 'Roseli Berry', 'Fairy'
makeBoostOnTypeItem 'Luminous Moss', 'Water', specialDefense: 1
makeBoostOnTypeItem 'Snowball', 'Ice', attack: 1
