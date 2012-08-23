class @ModifierChain
  constructor: ->
    @chain = []

  add: (priority, callback) =>
    if !callback?
      [callback, priority] = [priority, 0]
    [min, max, mid] = [0, @chain.length - 1, 0]
    while min <= max
      mid = Math.floor((min + max) / 2)
      if @chain[mid].priority > priority
        max = mid - 1
      else
        min = mid + 1
    @chain.splice(min, 0, {priority, callback})

  run: (move, battle, attacker, defender) =>
    modifier = 0x1000
    for {callback} in @chain
      prime = callback(move, battle, attacker, defender)
      # If prime is a 2-element array, break out early if 2nd element is true.
      if prime.length then [prime, shouldBreak] = prime
      modifier = Math.floor((modifier * prime + 0x800) / 0x1000)
      if shouldBreak then break
    modifier
