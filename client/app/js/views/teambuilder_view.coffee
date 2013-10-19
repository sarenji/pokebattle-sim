class @TeambuilderView extends Backbone.View
  template: JST['teambuilder']
  teamsTemplate: JST['teambuilder_teams']
  editTemplate: JST['teambuilder_pokemon']
  importTemplate: JST['modals/import_team']
  teamTemplate: JST['team']

  events:
    # Team view
    'click .select-team': 'clickTeam'
    'click .add-new-team': 'addNewTeam'

    # Pokemon view
    'click .change-gen-dropdown a': 'changeTeamGeneration'
    'blur .team_name': 'blurTeamName'
    'keypress .team_name': 'keypressTeamName'
    'click .go_back': 'goBackToOverview'
    'click .pokemon_list li': 'clickPokemon'
    'click .add_pokemon': 'addNewPokemonEvent'
    'click .save_team': 'saveTeams'
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

  initialize: (attributes) =>
    {@teams} = attributes
    @selectedPokemon = 0
    @selectedTeam = 0

    @loadTeams()

  clickTeam: (e) =>
    $team = $(e.currentTarget)
    index = $team.index()
    @selectedPokemon = 0
    @setSelectedTeamIndex(index)

  clickPokemon: (e) =>
    $listItem = $(e.currentTarget)
    index = @$('.pokemon_list li').index($listItem)
    @setSelectedPokemonIndex(index)

  attachEventsToTeam: (team) =>
    @listenTo(team, 'add', @renderPokemon)
    @listenTo(team, 'change:ivs', @renderStats)
    @listenTo(team, 'change:evs', @renderStats)
    @listenTo(team, 'change:nature', @renderStats)
    @listenTo(team, 'change:hiddenPowerType', @renderStats)
    @listenTo(team, 'change:shiny', @renderPokemon)
    @listenTo(team, 'change reset add remove', @dirty)

    # Todo: Make this perform better
    @listenTo(team, 'change:name change:forme', (pokemon) =>
      @renderPokemonList()
      @renderPokemon(pokemon)
    )

    @listenTo(team, 'add remove', @renderPokemonList)
    @listenTo(team, 'reset', @renderTeam)

  loadTeams: =>
    teamsJSON = window.localStorage.getItem("teams")
    if teamsJSON
      teamsJSON = JSON.parse(teamsJSON)
      for teamJSON in teamsJSON
        pokemonJSON.teambuilder = true  for pokemonJSON in teamJSON.pokemon
      @teams = teamsJSON.map (json) =>
        {pokemon} = json
        attributes = _.clone(json)
        delete attributes.pokemon
        team = new Team(pokemon, attributes)
        @attachEventsToTeam(team)
        team
    else
      @addNewTeam()
    @render()

  addEmptyPokemon: (team) =>
    team.add(new Pokemon(teambuilder: true))

  addNewTeam: =>
    team = new Team()
    @teams.push(team)
    @addNewPokemon(team)  for i in [1..6]
    @attachEventsToTeam(team)
    @saveTeams()
    @renderTeams()

  addNewPokemonEvent: =>
    @addNewPokemon(@teams[@selectedTeam])

  addNewPokemon: (team) =>
    @addEmptyPokemon(team)
    @$('.pokemon_list li').last().click()

  saveTeams: =>
    teamJSON = @teams.map((team) -> team.toJSON())
    # PokeBattle.socket.send('save team', teamJson)
    window.localStorage.setItem('teams', JSON.stringify(teamJSON))
    @resetHeaderButtons()

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

  changeTeamGeneration: (e) =>
    $link = $(e.currentTarget)
    generation = $link.data('generation')
    oldGeneration = @getSelectedTeam().generation
    if generation != oldGeneration
      @getSelectedTeam().generation = generation
      @renderTeam()
      @dirty()

  generationChanged: (generation) =>
    {MoveData, SpeciesData, ItemData} = window.Generations[generation.toUpperCase()]
    @moveData = MoveData
    @speciesList = (name for name, data of SpeciesData)
    # TODO: filter irrelevant items
    @itemList = _(name for name, data of ItemData).sort()
    @render()

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
    return false  if moveName not of @moveData
    type = @moveData[moveName].type.toLowerCase()
    $input.replaceWith("""<div class="button move-button #{type}">#{moveName}</div>""")
    return true

  setSelectedPokemonIndex: (index) =>
    pokemon = @getSelectedTeam().at(index)
    @selectedPokemon = index
    
    # Set the correct pokemon view to active
    @$(".pokemon_edit").children().hide().removeClass("active")
    @getPokemonView(pokemon).show().addClass("active")

    # Set the correct list item to active
    @$(".navigation li").removeClass("active")
    @$(".navigation li").eq(index).addClass("active")

  getSelectedPokemon: =>
    @getSelectedTeam().at(@selectedPokemon)

  setSelectedTeamIndex: (index) =>
    @selectedTeam = index
    @renderTeam()

  getSelectedTeam: =>
    @teams[@selectedTeam]

  getActivePokemonView: =>
    @getPokemonView(@getSelectedPokemon())

  getPokemonView: (pokemon) =>
    @$("div[data-cid=#{pokemon.cid}]")

  blurTeamName: =>
    teamName = @$('.team_name').text()
    @getSelectedTeam().name = teamName
    @dirty()

  keypressTeamName: (e) =>
    if e.which == 13  # [Enter]
      @$('.team_name').blur()

  goBackToOverview: =>
    if @_dirty
      @loadTeams()
      @resetHeaderButtons()
    @render()

  dirty: =>
    @$('.go_back').text('Discard changes')
    @$('.save_team').removeClass('disabled')
    @_dirty = true

  resetHeaderButtons: =>
    @$('.go_back').text('Back')
    @$('.save_team').addClass('disabled')

  render: =>
    @$el.html @template(pokemon: @getSelectedTeam(), selected: @selectedPokemon)
    @renderTeams()
    this

  renderTeams: =>
    @$('.display_teams').html @teamsTemplate(teams: @teams, window: window)
    @$('.display_teams').removeClass('hidden')
    @$('.display_pokemon').addClass('hidden')

  renderTeam: =>
    team = @getSelectedTeam()
    @generationChanged(team.generation || Team::defaultGeneration)
    @renderGeneration()
    @renderPokemonList(team)
    @renderPokemon(pokemon)  for pokemon in team.models
    @setSelectedPokemonIndex(@selectedPokemon)
    @$('.team_name').text(team.getName())
    @$('.display_teams').addClass('hidden')
    @$('.display_pokemon').removeClass('hidden')

  renderPokemonList: =>
    team = @getSelectedTeam()
    pokemon_list = @$(".pokemon_list")
    pokemon_list.empty()
    for pokemon, i in team.models
      $listItem = $("<li/>").data("pokemon-index", i)
      $listItem.text(pokemon.get("name"))
      $listItem.prepend($("<div/>").addClass("pokemon_icon")
        .attr("style", PokemonIconBackground(pokemon.get('name'),
                                             pokemon.get('forme'))))
      $listItem.addClass("active")  if @selectedPokemon == i
      pokemon_list.append($listItem)

    # Hide add pokemon if there's 6 pokemon
    if team.length < 6
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

  renderGeneration: =>
    generation = @getSelectedTeam().generation || Team::defaultGeneration
    text = @$(".change-gen-dropdown a[data-generation='#{generation}']").text()
    @$(".current-generation").text(text)

  renderModal: =>
    if $('#import-team-modal').length == 0
      $('body').append(@importTemplate())
    $modal = $('#import-team-modal')
    $modal.on 'click', '.import-team-submit', (e) =>
      teamString = $modal.find('.imported-team').val()
      teamJSON = PokeBattle.parseTeam(teamString)
      pokemonJSON.teambuilder = true  for pokemonJSON in teamJSON
      @getSelectedTeam().reset(teamJSON)
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
