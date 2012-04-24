require 'js-yaml'

solid = require 'solid'

{Engine} = require './engine'
engine = new Engine
  moves: require './data/bw/moves.yml'

solid (app) ->
  app.get '/', ->
    JSON.stringify(engine.moves)
