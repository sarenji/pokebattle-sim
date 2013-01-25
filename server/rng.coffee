class @FakeRNG
  constructor: ->

  next: (id) =>
    Math.random()

  # Returns a random integer N such that min <= N <= max.
  randInt: (min, max, id) =>
    Math.floor(@next(id) * (max + 1 - min) + min)

  # Returns a random element in the array.
  # Assumes the array is above length 0.
  choice: (array) =>
    index = @randInt(0, array.length - 1)
    array[index]
