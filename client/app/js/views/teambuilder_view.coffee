class @TeambuilderView extends Backbone.View
  template: JST['teambuilder']
  editTemplate: JST['teambuilder_main']

  events:
    'click .add_pokemon': 'addEmptyPokemon'

  initialize: =>
    @listenTo(@collection, 'add', @renderPokemon)

    @addEmptyPokemon()
    @selected = 0

    @render()

  addEmptyPokemon: =>
    @collection.add(new Pokemon(speciesId: 1, name: "Bulbasaur"))
    @renderPokemonList()

  setSelectedIndex: (index) =>
    pokemon = @collection.at(index)
    @selected = index
    @$el.find(".pokemon_edit").children().hide()
    @$el.find("div[data-cid=" + pokemon.cid + "]").show()

  render: =>
    @$el.html @template(pokemon: @collection, selected: @selected)
    @renderPokemonList()
    @renderPokemon(pokemon) for pokemon in @collection.models
    @setSelectedIndex(@selected)
    this

  renderPokemonList: => 
    pokemon_list = @$el.find(".pokemon_list")
    pokemon_list.empty()
    for pokemon, i in @collection.models
      list_item = $("<li/>").data("pokemon-index", i).text(pokemon.get("name"))
      list_item.addClass("active")  if @selected == i
      pokemon_list.append(list_item)

  renderPokemon: (pokemon) =>
    view = @$el.find("div[data-cid=" + pokemon.cid + "]")
    if view.length == 0
      view = $("<div/>").attr("data-cid", pokemon.cid).hide()
      @$el.find(".pokemon_edit").append(view)

    view.html @editTemplate(pokemon: pokemon)