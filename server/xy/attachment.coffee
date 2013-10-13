coffee = require 'coffee-script'
path = require('path').resolve(__dirname, '../bw/attachment.coffee')
eval(coffee.compile(require('fs').readFileSync(path, 'utf8'), bare: true))

delete @Status.Sleep::switchOut
