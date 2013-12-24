restify = require('restify')
generations = require('../server/generations')
learnsets = require('../shared/learnsets')
GenerationJSON = generations.GenerationJSON

getName = (name) ->
  require('./name_map.json')[name]

slugify = (str) ->
  str.toLowerCase().replace(/[^a-z0-9]/g, '-').replace(/\-{2,}/g, '-')

slugifyArray = (array) ->
  hash = {}
  for element in array
    hash[slugify(element)] = element
  hash

attachAPIEndpoints = (server) ->
  for gen in generations.ALL_GENERATIONS
    do (gen) ->
      json = GenerationJSON[gen.toUpperCase()]
      GenMoves = slugifyArray(json.MoveList)
      GenAbilities = slugifyArray(json.AbilityList)
      GenTypes = slugifyArray(json.TypeList)

      intGeneration = generations.GENERATION_TO_INT[gen]
      server.get "#{gen}/moves", (req, res, next) ->
        res.send(json.MoveData)
        return next()

      server.get "#{gen}/pokemon/:name", (req, res, next) ->
        name = getName(req.params.name)
        return next(new restify.ResourceNotFoundError("Could not find Pokemon: #{req.params.name}"))  if !name
        pokemon = json.FormeData[name]
        res.send(pokemon)
        return next()

      server.get "#{gen}/items", (req, res, next) ->
        res.send(items: json.ItemList)
        return next()

      server.get "#{gen}/moves", (req, res, next) ->
        res.send(moves: json.MoveList)
        return next()

      server.get "#{gen}/moves/:name", (req, res, next) ->
        move = GenMoves[req.params.name]
        return next(new restify.ResourceNotFoundError("Could not find Move: #{req.params.name}"))  if !move
        res.send(pokemon: json.MoveMap[move])
        return next()

      server.get "#{gen}/abilities", (req, res, next) ->
        res.send(abilities: json.AbilityList)
        return next()

      server.get "#{gen}/abilities/:name", (req, res, next) ->
        ability = GenAbilities[req.params.name]
        return next(new restify.ResourceNotFoundError("Could not find Ability: #{req.params.name}"))  if !ability
        res.send(pokemon: json.AbilityMap[ability])
        return next()

      server.get "#{gen}/types", (req, res, next) ->
        res.send(types: json.TypeList)
        return next()

      server.get "#{gen}/types/:name", (req, res, next) ->
        type = GenTypes[req.params.name]
        return next(new restify.ResourceNotFoundError("Could not find Type: #{req.params.name}"))  if !type
        res.send(pokemon: json.TypeMap[type])
        return next()

      server.get "#{gen}/pokemon/:name/moves", (req, res, next) ->
        name = getName(req.params.name)
        pokemon = {name: name}
        moves = learnsets.learnableMoves(GenerationJSON, pokemon, intGeneration)
        return next(new restify.ResourceNotFoundError("Could not find moves for Pokemon: #{req.params.name}"))  if !moves || moves.length == 0
        res.send(moves: moves)
        return next()

      server.get "#{gen}/pokemon/:name/check", (req, res, next) ->
        name = getName(req.params.name)
        return next(new restify.ResourceNotFoundError("Could not find Pokemon: #{req.params.name}"))  if !name
        pokemon = {name: name}
        moveset = req.query.moves?.split(/,/) || []
        valid = learnsets.checkMoveset(GenerationJSON, pokemon, intGeneration, moveset)
        errors = []
        errors.push("Invalid moveset")  if !valid
        res.send(errors: errors)
        return next()

      server.put "#{gen}/damagecalc", (req, res, next) ->
        # todo: catch any invalid data.
        moveName = req.params.move
        attacker = req.params.attacker
        defender = req.params.defender

        createPlayer = (id, p) -> { player: { id: id }, team: [p] }
        players = [createPlayer("0", attacker), createPlayer("1", defender)]

        {Battle} = require("../server/#{gen}/battle")
        battle = new Battle('id', players: players, numActive: 1, conditions: [])

        move = battle.getMove(moveName)
        if not move
          return next(new restify.BadRequest("Invalid move #{moveName}"))

        attackerPokemon = battle.getTeam("0").at(0)
        defenderPokemon = battle.getTeam("1").at(0)

        # bias the RNG to remove randmomness like critical hits
        require("../shared/bias_rng").makeBiasedRng(battle)
        battle.rng.bias("next", "ch", 1)
        battle.rng.bias("randInt", "miss", 0)
        battle.rng.bias("next", "secondary status", 0)

        # calculate min damage
        battle.rng.bias("randInt", "damage roll", 0)
        minDamage = move.calculateDamage(battle, attackerPokemon, defenderPokemon)

        # calculate max damage
        battle.rng.bias("randInt", "damage roll", 15)
        maxDamage = move.calculateDamage(battle, attackerPokemon, defenderPokemon)

        # TODO: Add remaining HP or anything else that's requested
        res.send(
          min:
            damage: minDamage
          max:
            damage: maxDamage
        )

        return next()

@createServer = (port, done) ->
  server = restify.createServer
    name: 'pokebattle-api'
    version: '0.0.0'
  server.pre(restify.pre.sanitizePath())
  server.use(restify.acceptParser(server.acceptable))
  server.use(restify.queryParser())
  server.use(restify.bodyParser())
  server.use(restify.gzipResponse())

  attachAPIEndpoints(server)

  server.listen port, ->
    console.log('%s listening at %s', server.name, server.url)
    done?()

  server
