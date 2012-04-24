solid = require 'solid'

solid (app) ->
  app.get '/', -> "Hello world!"
