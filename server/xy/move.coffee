coffee = require 'coffee-script'
path = require('path').resolve(__dirname, '../bw/move.coffee')
eval(coffee.compile(require('fs').readFileSync(path, 'utf8'), bare: true))

@Move::criticalMultiplier = 1.5
