coffee = require 'coffee-script'
path = require('path').resolve(__dirname, '../bw/battle.coffee')
eval(coffee.compile(require('fs').readFileSync(path, 'utf8'), bare: true))
