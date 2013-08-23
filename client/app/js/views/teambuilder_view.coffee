class @TeambuilderView extends Backbone.View
  template: JST['teambuilder']
  editTemplate: JST['teambuilder_main']

  events:
    'click .add_pokemon': 'addEmptyPokemon'
    'change .iv-entry': 'changeIv'
    'change .ev-entry': 'changeEv'

  initialize: =>
    @listenTo(@collection, 'add', @renderPokemon)
    @listenTo(@collection, 'change:ivs', @renderStats)
    @listenTo(@collection, 'change:evs', @renderStats)

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
    @$el.find("div[data-cid=#{pokemon.cid}]").show()

  getSelectedPokemon: =>
    @collection.at(@selected)

  changeIv: (ev) =>
    # todo: make changeIv and changeEv DRY
    $input = $(ev.target)
    stat = $input.data("stat")
    value = parseInt($input.val())
    if isNaN(value) || value > 31 || value < 0
      value = 31

    @getSelectedPokemon().setIv(stat, value)
    @renderStats()

  changeEv: (ev) =>
    # todo: make changeIv and changeEv DRY
    $input = $(ev.target)
    stat = $input.data("stat")
    value = parseInt($input.val())
    if isNaN(value) || value > 255 || value < 0
      value = 255 # todo: get highest possible ev

    @getSelectedPokemon().setEv(stat, value)
    @renderStats()

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
    view = @$el.find("div[data-cid=#{pokemon.cid}]")
    if view.length == 0
      view = $("<div/>").attr("data-cid", pokemon.cid).hide()
      @$el.find(".pokemon_edit").append(view)

    view.html @editTemplate(pokemon: pokemon)
    @renderStats()

  renderStats: =>
    pokemon = @getSelectedPokemon()
    $(".iv-entry").each ->
      $input = $(this)
      stat = $input.data("stat")
      $input.val(pokemon.iv(stat))

    $(".ev-entry").each ->
      $input = $(this)
      stat = $input.data("stat")
      $input.val(pokemon.ev(stat))

    # todo: render totals

