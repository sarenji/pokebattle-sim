class @Pokemon
  constructor: (attributes = {}) ->
    @name = attributes.name || 'Missingno'
    @level = attributes.level || 100
