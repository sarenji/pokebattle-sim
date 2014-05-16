class PokemonCollection extends Backbone.Collection
  model: (attrs, options) =>
    if attrs.name
      attrs.teambuilder = @parents[0].get('teambuilder')
      return new Pokemon(attrs, options)
    else
      return new NullPokemon()

class @Team extends Backbone.AssociatedModel
  relations: [
    type: Backbone.Many
    key:  'pokemon'
    collectionType: PokemonCollection
  ]

  initialize: (attrs={}, options={}) =>
    @owner = attrs.owner
    @set('generation', DEFAULT_GENERATION)  unless attrs.generation
    @set('teambuilder', true)  if options.teambuilder

  getName: =>
    @get('name') || "Untitled team"

  toJSON: =>
    json = {}
    json['id'] = @id  if @id
    json['name'] = @get('name')
    json['generation'] = @get('generation')
    json['pokemon'] = @get('pokemon').toJSON()
    json

  # Returns the pokemon at a particular index. Delegates to the internal pokemon collection
  at: (idx) => @get('pokemon').at(idx)

  # Returns which index the pokemon is in
  indexOf: (idx) => @get('pokemon').indexOf(idx)

  # Replace a pokemon at a particular index for another
  replace: (idx, newPokemon) =>
    @get('pokemon').remove(@get('pokemon').at(idx))
    @get('pokemon').add(newPokemon, at: idx)

  # Equivalent to toJSON, but omits NullPokemon
  toNonNullJSON: =>
    id: @id
    name: @get('name')
    generation: @get('generation')
    pokemon: @get('pokemon')
      .reject((pokemon) -> pokemon.isNull)
      .map((pokemon) -> pokemon.toJSON())

  clone: =>
    attrs = _(@attributes).clone()
    attrs.pokemon = @get('pokemon').toJSON()
    new Team(attrs)

  rearrange: (arrangement) ->
    pokemon = @get('pokemon')
    pokemon.reset((pokemon.models[index]  for index in arrangement))
    return true

  getGeneration: (generation) ->
    gen = @get('generation') || DEFAULT_GENERATION
    gen = gen.toUpperCase()
    window.Generations[gen]

  getPBV: =>
    gen = @getGeneration()
    pokemon = @get('pokemon').toJSON()
    PokeBattle.PBV.determinePBV(gen, pokemon)

  getNonNullPokemon: =>
    @get('pokemon').where(isNull: false)

  hasNonNullPokemon: =>
    @get('pokemon').some((pokemon) -> not pokemon.isNull)

  sync: (method) =>
    switch method
      when 'create', 'patch', 'update'
        PokeBattle.socket.send('saveTeam', @toJSON(), @cid)
      when 'delete'
        PokeBattle.socket.send('destroyTeam', @id)
