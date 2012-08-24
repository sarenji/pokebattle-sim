class @TeamBuilderView extends Backbone.View
  template: JST['teambuilder']

  events:
    'click .builder_pokemon': 'clickPokemon'
    'click .builder_add_pokemon': 'addPokemon'

  initialize: =>
    @selected = null

  render: =>
    @$el.html @template(pokemon: @collection, selected: @selected)
    this

  clickPokemon: (e) =>
    # Normalize $target
    $target = $(e.target)
    if !$target.hasClass('builder_pokemon')
      $target = $target.closest('.builder_pokemon')

    if @selected == $target.index()
      # Deselect if already selected.
      @selected = null
    else
      # Select Pokemon.
      @selected = $target.index()
    @render()

  addPokemon: =>
    @collection.add(new Pokemon())
    @render()
