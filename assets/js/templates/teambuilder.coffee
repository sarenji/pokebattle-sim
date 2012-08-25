JST['teambuilder'] = thermos.template (locals) ->
  @div '.builder_team', ->
    locals.pokemon.each (pokemon, i) =>
      klass = '.builder_pokemon'
      klass += '.selected'  if i == locals.selected
      @div klass, pokemon.name
    # @div '.builder_add_pokemon', '+'
  # TODO: Don't use bind. Honestly, thermos should be passing locals for you.
  @div '.builder_detail', JST['teambuilder_detail'].bind(this, locals)
