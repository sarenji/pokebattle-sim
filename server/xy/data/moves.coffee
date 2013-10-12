coffee = require 'coffee-script'
path = require('path').resolve(__dirname, '../../bw/data/moves.coffee')
eval(coffee.compile(require('fs').readFileSync(path, 'utf8'), bare: true))

extendMove 'Hidden Power', ->
  @basePower = -> @power
