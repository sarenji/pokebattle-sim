@makeBiasedRng = (battle) ->
  biasedRNGFuncs = {}
  for funcName in ['next', 'randInt']
    do (funcName) =>
      oldFunc = battle.rng[funcName].bind(battle.rng)
      battle.rng[funcName] = (args...) =>
        id = args[args.length - 1]
        func = biasedRNGFuncs[funcName]
        return (if id of func then func[id] else oldFunc(args...))

  battle.rng.bias = (funcName, id, returns) ->
    biasedRNGFuncs[funcName] ||= {}
    biasedRNGFuncs[funcName][id] = returns