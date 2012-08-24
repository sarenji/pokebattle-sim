JST['teambuilder_detail'] = thermos.template (locals) ->
  pokemon = locals.pokemon.at(locals.selected)
  if pokemon?
    # TODO: Display detail
    @h2 pokemon.get('name')
