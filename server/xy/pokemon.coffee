coffee = require 'coffee-script'
path = require('path').resolve(__dirname, '../bw/pokemon.coffee')
eval(coffee.compile(require('fs').readFileSync(path, 'utf8')))
