class PokemonCollection extends Backbone.Collection
  model: (attrs, options) =>
    # History lesson: We stored species under `name`. Now that we support
    # nicknames, we need the `name` freed up. However, teams are saved to the
    # server using the old scheme. Therefore we need to do a simple check for
    # the existence of `species`; if it exists, do nothing. If not, use `name`.
    if attrs.name || attrs.species
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
    @set('pokemon', [])  unless attrs.pokemon

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

  getFormat: =>
    format = @get('generation')  # TODO: Migrate to format
    format = DEFAULT_FORMAT  if format not of Formats
    Formats[format]

  getGeneration: (generation) ->
    gen = generation || @getFormat().generation
    gen = gen.toUpperCase()
    window.Generations[gen]

  getPBV: =>
    gen = @getGeneration()
    pokemon = @get('pokemon').toJSON()
    PokeBattle.PBV.determinePBV(gen, pokemon)

  getMaxPBV: =>
    {conditions} = @getFormat()
    if Conditions.PBV_1000 in conditions
      1000
    else if Conditions.PBV_500 in conditions
      500
    else
      0

  hasPBV: =>
    @getMaxPBV() > 0

  getNonNullPokemon: =>
    @get('pokemon').where(isNull: false)

  hasNonNullPokemon: =>
    @get('pokemon').some((pokemon) -> not pokemon.isNull)

  sync: (method) =>
    switch method
      when 'create', 'patch', 'update'
        @trigger('saving', this)
        PokeBattle.primus.send 'saveTeam', @toJSON(), (id) =>
          # Note: If this model is saved multiple times, then this won't
          # tell you if some of the saves failed.
          @set('id', id)
          @trigger('saved', this)
      when 'delete'
        PokeBattle.primus.send('destroyTeam', @id)  if @id
