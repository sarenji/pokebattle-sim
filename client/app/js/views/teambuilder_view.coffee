class @TeambuilderView extends Backbone.View
  template: JST['teambuilder']
  editTemplate: JST['teambuilder_main']
  importTemplate: JST['modals/import_team']

  events:
    'click .pokemon_list li': 'clickPokemon'
    'click .add_pokemon': 'addNewPokemon'
    'click .save_team': 'saveTeam'
    'click .import_team': 'renderModal'
    'change .species_list': 'changeSpecies'
    'change .selected-forme': 'changeForme'
    'change .selected_nature': 'changeNature'
    'change .selected_ability': 'changeAbility'
    'change .selected_item': 'changeItem'
    'change .selected_shininess': 'changeShiny'
    'change .iv-entry': 'changeIv'
    'change .ev-entry': 'changeEv'
    'change .select-hidden-power': 'changeHiddenPower'
    'keyup .selected_moves input': 'keyupMoves'
    'blur .selected_moves input': 'blurMoves'
    'click .table-moves tbody tr': 'clickMoveName'
    'click .move-button': 'clickSelectedMove'

  initialize: =>
    # TODO: Save these to something more global
    @speciesList = (name for name, data of SpeciesData)
    @itemList = _(name for name, data of ItemData).sort() # todo: filter irrelevant items
    @selected = 0

    @listenTo(@collection, 'add', @renderPokemon)
    @listenTo(@collection, 'change:ivs', @renderStats)
    @listenTo(@collection, 'change:evs', @renderStats)
    @listenTo(@collection, 'change:nature', @renderStats)
    @listenTo(@collection, 'change:hiddenPowerType', @renderStats)
    @listenTo(@collection, 'change:shiny', @renderPokemon)

    # Todo: Make this perform better
    @listenTo(@collection, 'change:name change:forme', (pokemon) =>
      @renderPokemonList()
      @renderPokemon(pokemon)
    )

    @listenTo(@collection, 'add remove', @renderPokemonList)

    @loadTeam()

    @render()

  clickPokemon: (e) =>
    $listItem = $(e.currentTarget)
    index = @$('.pokemon_list li').index($listItem)
    @setSelectedIndex(index)

  loadTeam: =>
    teamJSON = window.localStorage.getItem("team")
    if teamJSON
      teamJSON = JSON.parse(teamJSON)
      @collection.reset(teamJSON)
    else
      @addNewPokemon()  for i in [1..6]

  addEmptyPokemon: =>
    @collection.add(new Pokemon())

  addNewPokemon: =>
    @addEmptyPokemon()
    @$('.pokemon_list li').last().click()

  saveTeam: =>
    teamJSON = @collection.toJSON()
    # PokeBattle.socket.send('save team', teamJson)
    window.localStorage.setItem('team', JSON.stringify(teamJSON))

  changeSpecies: (e) =>
    $list = $(e.currentTarget)
    @getSelectedPokemon().set("name", $list.val())

  changeForme: (e) =>
    $forme = $(e.currentTarget)
    @getSelectedPokemon().set('forme', $forme.val())

  changeNature: (e) =>
    $list = $(e.currentTarget)
    @getSelectedPokemon().set("nature", $list.val())

  changeAbility: (e) =>
    $list = $(e.currentTarget)
    @getSelectedPokemon().set("ability", $list.val())

  changeItem: (e) =>
    $list = $(e.currentTarget)
    @getSelectedPokemon().set("item", $list.val())

  changeShiny: (e) =>
    $checkbox = $(e.currentTarget)
    @getSelectedPokemon().set("shiny", $checkbox.is(":checked"))

  changeIv: (e) =>
    # todo: make changeIv and changeEv DRY
    $input = $(e.currentTarget)
    stat = $input.data("stat")
    value = parseInt($input.val())
    if isNaN(value) || value > 31 || value < 0
      value = 31

    pokemon = @getSelectedPokemon()
    pokemon.setIv(stat, value)

  changeEv: (e) =>
    # todo: make changeIv and changeEv DRY
    $input = $(e.currentTarget)
    stat = $input.data("stat")
    value = parseInt($input.val())
    value = 252  if isNaN(value) || value > 252 || value < 0

    pokemon = @getSelectedPokemon()
    value = pokemon.setEv(stat, value)
    $input.val(value)

  changeHiddenPower: (e) =>
    $input = $(e.currentTarget)
    type = $input.val()
    pokemon = @getSelectedPokemon()
    pokemon.set('hiddenPowerType', type.toLowerCase())

  keyupMoves: (e) =>
    $input = $(e.currentTarget)
    return  if $input.val().length == 0
    $table = @getActivePokemonView().find('.table-moves')
    $allMoves = $table.find('tbody tr')
    switch e.which
      when 13  # [Enter]; we're selecting the active move.
        $activeMove = @$selectedMove()
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
        moveName = $input.val()
        @filterMovesBy(moveName)

  filterMovesBy: (moveName) =>
    $table = @getActivePokemonView().find('.table-moves')
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

  blurMoves: (e) =>
    $input = $(e.currentTarget)
    return  if $input.val().length == 0
    moveName = @$selectedMove().data('move-id')
    @insertMove($input, moveName)

  clickMoveName: (e) =>
    $this = $(e.currentTarget)
    moveName = $this.data('move-id')
    $moves = @getActivePokemonView().find('.selected_moves')
    $input = $moves.find('input:focus').first()
    $input ||= $moves.find('input').first()
    return  if $input.length == 0
    @insertMove($input, moveName)

  insertMove: ($input, moveName) =>
    return  if !@buttonify($input, moveName)
    $moves = @getActivePokemonView().find('.selected_moves')
    $moves.find('input').first().focus()

    # Record moves
    movesArray = []
    $moves.find('.move-button').each ->
      moveName = $(this).text().trim()
      if moveName != ""
        movesArray.push(moveName)
    @getSelectedPokemon().set("moves", movesArray)

  $selectedMove: =>
    $table = @getActivePokemonView().find('.table-moves')
    $allMoves = $table.find('tbody tr')
    $allMoves.filter('.active').first()

  clickSelectedMove: (e) =>
    $this = $(e.currentTarget)
    $input = $("<input type='text' value='#{$this.text()}'/>")
    $this.replaceWith($input)
    $input.focus()

  buttonify: ($input, moveName) =>
    return false  if moveName not of MoveData
    type = MoveData[moveName].type.toLowerCase()
    $input.replaceWith("""<div class="button move-button #{type}">#{moveName}</div>""")
    return true

  setSelectedIndex: (index) =>
    pokemon = @collection.at(index)
    @selected = index
    
    # Set the correct pokemon view to active
    @$(".pokemon_edit").children().hide().removeClass("active")
    @getPokemonView(pokemon).show().addClass("active")

    # Set the correct list item to active
    @$(".navigation li").removeClass("active")
    @$(".navigation li").eq(index).addClass("active")

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
        .attr("style", PokemonIconBackground(pokemon.get('name'),
                                             pokemon.get('forme'))))
      $listItem.addClass("active")  if @selected == i
      pokemon_list.append($listItem)

    # Hide add pokemon if there's 6 pokemon
    if @collection.length < 6
      @$(".add_pokemon").show()
    else
      @$(".add_pokemon").hide()

  renderPokemon: (pokemon) =>
    view = @getPokemonView(pokemon)
    if view.length == 0
      view = $("<div/>").attr("data-cid", pokemon.cid).hide()
      @$(".pokemon_edit").append(view)

    view.html @editTemplate(window: window, speciesList: @speciesList, itemList: @itemList, pokemon: pokemon)
    @renderStats(pokemon)

    @$('.selected_moves input').each (i, el) =>
      $this = $(el)
      moveName = $this.val()
      @buttonify($this, moveName)
    this

  renderModal: =>
    if $('#import-team-modal').length == 0
      $('body').append(@importTemplate())
    $modal = $('#import-team-modal')
    $modal.on 'click', '.import-team-submit', (e) =>
      teamString = $modal.find('.imported-team').val()
      teamJSON = PokeBattle.parseTeam(teamString)
      @collection.reset(teamJSON)
      @render()
      $modal.modal('hide')
      return false
    $modal.modal('show')

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

    $div.find('.total-evs').text("Total EVs: #{pokemon.getTotalEVs()}/510")
    $div.find('.select-hidden-power').val(pokemon.get('hiddenPowerType'))
