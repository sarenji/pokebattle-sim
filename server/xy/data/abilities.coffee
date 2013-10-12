coffee = require 'coffee-script'
path = require('path').resolve(__dirname, '../../bw/data/abilities.coffee')
eval(coffee.compile(require('fs').readFileSync(path, 'utf8')))
