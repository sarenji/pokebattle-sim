class @FakeRNG
  constructor: ->

  next: =>
    Math.random()

  # Returns a random integer N such that min <= N <= max.
  randInt: (min, max) =>
    Math.floor(@next() * (max + 1 - min) + min)
