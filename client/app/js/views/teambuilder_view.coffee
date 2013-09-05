class @TeambuilderView extends Backbone.View
  template: JST['teambuilder']
  editTemplate: JST['teambuilder_main']

  events:
    'click .pokemon_list li': 'clickPokemon'
    'click .add_pokemon': 'addEmptyPokemon'
    'click .save_team': 'saveTeam'
    'change .species_list': 'changeSpecies'
    'change .selected_ability': 'changeAbility'
    'change .selected_item': 'changeItem'
    'change .iv-entry': 'changeIv'
    'change .ev-entry': 'changeEv'
    'change .selected_moves input': 'changeMoves'

  initialize: =>
    # TODO: Save these to something more global
    @speciesList = (name for name, data of SpeciesData)
    @itemList = _(name for name, data of ItemData).sort() # todo: filter irrelevant items

    @listenTo(@collection, 'add', @renderPokemon)
    @listenTo(@collection, 'change:ivs', @renderStats)
    @listenTo(@collection, 'change:evs', @renderStats)

    # Todo: Make this perform better
    @listenTo(@collection, 'change:name', (pokemon) =>
      @renderPokemonList()
      @renderPokemon(pokemon)
    )

    @addEmptyPokemon()
    @selected = 0

    @render()

  clickPokemon: (ev) =>
    $listItem = $(ev.target)
    index = $('.pokemon_list li').index($listItem)
    @setSelectedIndex(index)

  addEmptyPokemon: =>
    @collection.add(new Pokemon())
    @renderPokemonList()

  saveTeam: =>
    teamJson = @collection.toJSON()
    PokeBattle.socket.send('save team', teamJson)

  changeSpecies: (ev) =>
    $list = $(ev.target)
    @getSelectedPokemon().set("name", $list.val())

  changeAbility: (ev) =>
    $list = $(ev.target)
    @getSelectedPokemon().set("ability", $list.val())

  changeItem: (ev) =>
    $list = $(ev.target)
    @getSelectedPokemon().set("item", $list.val())

  changeIv: (ev) =>
    # todo: make changeIv and changeEv DRY
    $input = $(ev.target)
    stat = $input.data("stat")
    value = parseInt($input.val())
    if isNaN(value) || value > 31 || value < 0
      value = 31

    pokemon = @getSelectedPokemon()
    pokemon.setIv(stat, value)
    @renderStats(pokemon)

  changeEv: (ev) =>
    # todo: make changeIv and changeEv DRY
    $input = $(ev.target)
    stat = $input.data("stat")
    value = parseInt($input.val())
    if isNaN(value) || value > 255 || value < 0
      value = 255 # todo: get highest possible ev

    pokemon = @getSelectedPokemon()
    pokemon.setEv(stat, value)
    @renderStats(pokemon)

  changeMoves: (ev) =>
    pokemon = @getSelectedPokemon()
    movesArray = []
    @getPokemonView(pokemon).find(".selected_moves input").each ->
      moveName = $(this).val().trim()
      if moveName != ""
        movesArray.push(moveName)
    pokemon.set("moves", movesArray)

  setSelectedIndex: (index) =>
    pokemon = @collection.at(index)
    @selected = index
    @$(".pokemon_edit").children().hide().removeClass("active")
    @getPokemonView(pokemon).show().addClass("active")

  getSelectedPokemon: =>
    @collection.at(@selected)

  getActivePokemonView: =>
    @getPokemonView(@getSelectedPokemon())

  getPokemonView: (pokemon) =>
    @$("div[data-cid=#{pokemon.cid}]")

  render: =>
    @$el.html @template(pokemon: @collection, selected: @selected)
    @renderPokemonList()
    @renderPokemon(pokemon)  for pokemon in @collection.models
    @setSelectedIndex(@selected)
    this

  renderPokemonList: => 
    pokemon_list = @$(".pokemon_list")
    pokemon_list.empty()
    for pokemon, i in @collection.models
      list_item = $("<li/>").data("pokemon-index", i).text(pokemon.get("name"))
      list_item.addClass("active")  if @selected == i
      pokemon_list.append(list_item)

  renderPokemon: (pokemon) =>
    view = @getPokemonView(pokemon)
    if view.length == 0
      view = $("<div/>").attr("data-cid", pokemon.cid).hide()
      @$(".pokemon_edit").append(view)

    view.html @editTemplate(speciesList: @speciesList, itemList: @itemList, pokemon: pokemon)
    @renderStats(pokemon)

  renderStats: (pokemon) =>
    $div = @getPokemonView(pokemon)

    $div.find(".iv-entry").each ->
      $input = $(this)
      stat = $input.data("stat")
      $input.val(pokemon.iv(stat))

    $div.find(".ev-entry").each ->
      $input = $(this)
      stat = $input.data("stat")
      $input.val(pokemon.ev(stat))

    # todo: render totals

