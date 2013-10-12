coffee = require 'coffee-script'
path = require('path').resolve(__dirname, '../bw/battle_controller.coffee')
eval(coffee.compile(require('fs').readFileSync(path, 'utf8'), bare: true))
