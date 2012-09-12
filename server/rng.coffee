class @FakeRNG
  constructor: ->

  next: =>
    Math.random()

  # Returns a random integer N such that min <= N <= max.
  randInt: (min, max) =>
    Math.floor(@next() * (max + 1 - min) + min)

  # Returns a random element in the array.
  # Assumes the array is above length 0.
  choice: (array) =>
    index = @randInt(0, array.length - 1)
    array[index]
