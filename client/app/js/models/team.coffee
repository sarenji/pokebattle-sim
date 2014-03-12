class PokemonCollection extends Backbone.Collection
  initialize: (attrs, options) =>
    @team = options.team

  model: (attrs, options) =>
    if attrs.name
      attrs.teambuilder = @team.get('teambuilder')
      return new Pokemon(attrs, options)
    else
      return new NullPokemon()

class @Team extends Backbone.Model
  initialize: (attrs={}, options={}) =>
    @owner = attrs.owner
    @set('generation', DEFAULT_GENERATION)  unless attrs.generation
    @pokemon = new PokemonCollection(attrs.pokemon, team: this)
    @models = @pokemon.models
    @length = @pokemon.length

    # update certain attributes when the pokemon collection is changed
    @listenTo(@pokemon, 'change', => @models = @pokemon.models)
    @listenTo(@pokemon, 'add remove reset', => @length = @pokemon.length)

    # When any event fires for the sub collection, the change event is fired for the team.
    # To listen to pokemon directly, listen to @pokemon
    @listenTo(@pokemon, 'add remove change', => @trigger('change'))

    # Do not store the raw json, but the actual nested models
    @set('pokemon', @pokemon)

  getName: =>
    @get('name') || "Untitled team"

  toJSON: => {
      id: @id
      name: @get('name')
      generation: @get('generation')
      pokemon: @pokemon.toJSON()
    }

  # Returns the pokemon at a particular index. Delegates to the internal pokemon collection
  at: (idx) => @pokemon.at(idx)

  # Returns which index the pokemon is in
  indexOf: (idx) => @pokemon.indexOf(idx)

  # Replace a pokemon at a particular index for another
  replace: (idx, newPokemon) =>
    @pokemon.remove(@pokemon.at(idx))
    @pokemon.add(newPokemon, at: idx)

  # Equivalent to toJSON, but omits NullPokemon
  toNonNullJSON: =>
    id: @id
    name: @get('name')
    generation: @get('generation')
    pokemon: _.chain(@models)
      .reject((pokemon) -> pokemon.isNull)
      .map((pokemon) -> pokemon.toJSON())
      .value()

  clone: =>
    attrs = _(@attributes).clone()
    attrs.pokemon = @pokemon.toJSON()
    new Team(attrs)

  rearrange: (arrangement) ->
    @models = (@models[index]  for index in arrangement)
    @pokemon.models = @models
    return true

  getGeneration: (generation) ->
    gen = @get('generation') || DEFAULT_GENERATION
    gen = gen.toUpperCase()
    window.Generations[gen]

  getPBV: =>
    gen = @getGeneration()
    pokemonList = _(@models).pluck("attributes")
    PokeBattle.PBV.determinePBV(gen, pokemonList)

  getNonNullPokemon: =>
    _(@models).where(isNull: false)

  hasNonNullPokemon: =>
    _(@models).some((model) -> not model.isNull)

  save: =>
    PokeBattle.TeamStore.saveTeam(this)
    @trigger('sync')

  destroy: =>
    PokeBattle.TeamStore.destroyTeam(this)
    @trigger('destroy')