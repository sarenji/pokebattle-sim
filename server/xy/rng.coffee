coffee = require 'coffee-script'
path = require('path').resolve(__dirname, '../bw/rng.coffee')
eval(coffee.compile(require('fs').readFileSync(path, 'utf8'), bare: true))
