coffee = require 'coffee-script'
path = require('path').resolve(__dirname, '../bw/priorities.coffee')
eval(coffee.compile(require('fs').readFileSync(path, 'utf8')))
