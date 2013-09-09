class @TeambuilderView extends Backbone.View
  template: JST['teambuilder']
  editTemplate: JST['teambuilder_main']

  events:
    'click .pokemon_list li': 'clickPokemon'
    'click .add_pokemon': 'addEmptyPokemon'
    'click .save_team': 'saveTeam'
    'change .species_list': 'changeSpecies'
    'change .selected_nature': 'changeNature'
    'change .selected_ability': 'changeAbility'
    'change .selected_item': 'changeItem'
    'change .iv-entry': 'changeIv'
    'change .ev-entry': 'changeEv'
    'keydown .selected_moves input': 'keydownMoves'
    'focus .selected_moves input': 'keydownMoves'
    'click .table-moves tbody tr': 'selectMove'
    'click .move-button': 'deselectMove'

  initialize: =>
    # TODO: Save these to something more global
    @speciesList = (name for name, data of SpeciesData)
    @itemList = _(name for name, data of ItemData).sort() # todo: filter irrelevant items

    @listenTo(@collection, 'add', @renderPokemon)
    @listenTo(@collection, 'change:ivs', @renderStats)
    @listenTo(@collection, 'change:evs', @renderStats)
    @listenTo(@collection, 'change:nature', @renderStats)

    # Todo: Make this perform better
    @listenTo(@collection, 'change:name', (pokemon) =>
      @renderPokemonList()
      @renderPokemon(pokemon)
    )

    @listenTo(@collection, 'add remove', @renderPokemonList)

    @addEmptyPokemon()
    @selected = 0

    @render()

  clickPokemon: (ev) =>
    $listItem = $(ev.target)
    index = $('.pokemon_list li').index($listItem)
    @setSelectedIndex(index)

  addEmptyPokemon: =>
    @collection.add(new Pokemon())

  saveTeam: =>
    teamJson = @collection.toJSON()
    PokeBattle.socket.send('save team', teamJson)

  changeSpecies: (ev) =>
    $list = $(ev.target)
    @getSelectedPokemon().set("name", $list.val())

  changeNature: (e) =>
    $list = $(e.currentTarget)
    @getSelectedPokemon().set("nature", $list.val())

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
    value = 252  if isNaN(value) || value > 252 || value < 0

    pokemon = @getSelectedPokemon()
    pokemon.setEv(stat, value)
    @renderStats(pokemon)

  keydownMoves: (e) =>
    $table = @$('.table-moves')
    $allMoves = $table.find('tbody tr')
    switch e.which
      when 9, 13  # [Tab]/[Enter]; we're selecting the active move.
        $activeMove = $allMoves.filter('.active').first()
        $activeMove.click()
      when 38  # [Up arrow]; selects move above
        $activeMove = $allMoves.filter('.active').first()
        $prevMove = $activeMove.prevAll(":visible").first()
        if $prevMove.length > 0
          $activeMove.removeClass('active')
          $prevMove.addClass('active')
      when 40  # [Down arrow]; selects move below
        $activeMove = $allMoves.filter('.active').first()
        $nextMove = $activeMove.nextAll(":visible").first()
        if $nextMove.length > 0
          $activeMove.removeClass('active')
          $nextMove.addClass('active')
      else
        # Otherwise we're filtering moves
        $this = $(e.currentTarget)
        moveName = $this.val()
        @filterMovesBy(moveName)

  filterMovesBy: (moveName) =>
    $table = @$('.table-moves')
    $allMoves = $table.find('tbody tr')
    moveRegex = new RegExp(moveName, "i")
    $moves = $allMoves.filter ->
      $move = $(this)
      moveName = $move.data('move-id')
      moveRegex.test(moveName)
    $table.addClass('hidden')
    $moves.removeClass('hidden')
    $allMoves.not($moves).addClass('hidden')
    $allMoves.removeClass('active')
    $moves.first().addClass('active')
    $table.removeClass('hidden')

  hideMoves: =>
    $table = @$('.table-moves')
    $table.addClass('hidden')

  selectMove: (e) =>
    $this = $(e.currentTarget)
    moveName = $this.data('move-id')
    type = MoveData[moveName].type.toLowerCase()
    $moves = @$('.selected_moves')
    $input = $moves.find('input').first()
    $input.replaceWith("""<div class="button move-button #{type}">#{moveName}</div>""")
    $moves.find('input').first().focus()

    # Record moves
    movesArray = []
    $moves.find('.move-button').each ->
      moveName = $(this).text().trim()
      if moveName != ""
        movesArray.push(moveName)
    @getSelectedPokemon().set("moves", movesArray)

  deselectMove: (e) =>
    $this = $(e.currentTarget)
    $input = $("<input type='text' value='#{$this.text()}'/>")
    $this.replaceWith($input)
    $input.focus()

  setSelectedIndex: (index) =>
    pokemon = @collection.at(index)
    @selected = index
    
    # Set the correct pokemon view to active
    @$(".pokemon_edit").children().hide().removeClass("active")
    @getPokemonView(pokemon).show().addClass("active")

    # Set the correct list item to active
    @$(".navigation li").removeClass("active")
    $(@$(".navigation li").get(index)).addClass("active")

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
      $listItem = $("<li/>").data("pokemon-index", i)
      $listItem.text(pokemon.get("name"))
      $listItem.prepend($("<div/>").addClass("pokemon_icon")
        .attr("style", PokemonIconBackground(pokemon.get('name'))))
      $listItem.addClass("active")  if @selected == i
      pokemon_list.append($listItem)

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

    $div.find('.stat-total').each ->
      $this = $(this)
      stat = $this.data("stat")
      $this.text(pokemon.stat(stat))
