class @TeambuilderView extends Backbone.View
  template: JST['teambuilder/main']
  teamsTemplate: JST['teambuilder/teams']
  pokemonListTemplate: JST['teambuilder/pokemon_list']
  editTemplate: JST['teambuilder/pokemon']
  speciesTemplate: JST['teambuilder/species']
  nonStatsTemplate: JST['teambuilder/non_stats']
  movesTemplate: JST['teambuilder/moves']
  importTemplate: JST['modals/import_team']
  exportTemplate: JST['modals/export_team']
  teamTemplate: JST['team']

  events:
    # Team view
    'click .add-new-team': 'addNewTeamEvent'
    'click .export-team': 'exportTeam'
    'click .clone-team': 'cloneTeam'
    'click .delete-team': 'deleteTeam'
    'click .select-team': 'clickTeam'
    'click .import-team': 'renderImportTeamModal'

    # Pokemon view
    'click .change-gen-dropdown a': 'changeTeamGeneration'
    'blur .team_name': 'blurTeamName'
    'keypress .team_name': 'keypressTeamName'
    'click .go_back': 'goBackToOverview'
    'click .pokemon_list li': 'clickPokemon'
    'click .add_pokemon': 'addNewPokemonEvent'
    'click .save_team': 'saveTeams'
    'change .species_list': 'changeSpecies'
    'change .selected-forme': 'changeForme'
    'change .selected_nature': 'changeNature'
    'change .selected_ability': 'changeAbility'
    'change .selected_item': 'changeItem'
    'change .selected_gender': 'changeGender'
    'change .selected_level': 'changeLevel'
    'change .selected_shininess': 'changeShiny'
    'change .iv-entry': 'changeIv'
    'focus .ev-entry': 'focusEv'
    'blur .ev-entry': 'changeEv'
    'change .ev-entry': 'changeEv'
    'change .select-hidden-power': 'changeHiddenPower'
    'keydown .selected_moves input': 'keydownMoves'
    'blur .selected_moves input': 'blurMoves'
    'click .table-moves tbody tr': 'clickMoveName'
    'mousedown .table-moves': 'preventBlurMoves'
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
    @listenTo(team, 'change:level', @renderStats)
    @listenTo(team, 'change:ivs', @renderStats)
    @listenTo(team, 'change:evs', @renderStats)
    @listenTo(team, 'change:nature', @renderStats)
    @listenTo(team, 'change:hiddenPowerType', @renderStats)
    @listenTo(team, 'change:shiny', @renderPokemon)

    # Todo: Make this perform better
    @listenTo(team, 'change:name change:forme', (pokemon) =>
      @renderPokemonList()
      @renderPokemon(pokemon)
    )

    @listenTo(team, 'add remove', @renderPokemonList)
    @listenTo(team, 'reset', @renderTeam)
    @listenTo(team, 'change reset add remove', @dirty)
    @listenTo(team, 'change reset add remove', @renderPBV)

  loadTeams: =>
    @teams = PokeBattle.TeamStore.getTeams(teambuilder: true)
    @teams.map(@attachEventsToTeam)
    @addNewTeam()  if @teams.length == 0
    @render()

  addEmptyPokemon: (team) =>
    team.add(new NullPokemon())

  addNewTeamEvent: (e) =>
    @addNewTeam()

  addNewTeam: (team) =>
    team ||= new Team()
    @teams.push(team)
    @addEmptyPokemon(team)  while team.length < 6
    @attachEventsToTeam(team)
    @saveTeams()
    @renderTeams()

  cloneTeam: (e) =>
    $team = $(e.currentTarget).closest('.select-team')
    index = $team.index()
    @addNewTeam(@teams[index].clone())
    return false

  deleteTeam: (e) =>
    return false  if !confirm("Do you really want to delete this team?")
    $team = $(e.currentTarget).closest('.select-team')
    index = $team.index()
    @teams.splice(index, 1)
    @saveTeams()
    @renderTeams()
    return false

  exportTeam: (e) =>
    if $('#export-team-modal').length == 0
      $('body').append(@exportTemplate())
    $team = $(e.currentTarget).closest('.select-team')
    index = $team.index()
    if not @teams[index].hasNonNullPokemon()
      alert("You cannot export empty teams. Please add some pokemon first.")
      return false

    teamJSON = @teams[index].toNonNullJSON()
    teamString = PokeBattle.exportTeam(teamJSON.pokemon)

    $modal = $('#export-team-modal')
    $modal.find('.exported-team').val(teamString)
    $modal.modal('show')
    $modal.find('textarea, input').first().focus().select()
    return false

  addNewPokemonEvent: =>
    @addNewPokemon(@teams[@selectedTeam])

  addNewPokemon: (team) =>
    @addEmptyPokemon(team)
    @$('.pokemon_list li').last().click()

  # TODO: phase this out: updating all teams is way too inefficient
  # Also this is not using the TeamStore as it should
  saveTeams: =>
    teamJSON = @teams.map((team) -> team.toJSON())
    # PokeBattle.socket.send('save team', teamJson)
    window.localStorage.setItem('teams', JSON.stringify(teamJSON))
    @resetHeaderButtons()

  changeSpecies: (e) =>
    species = $(e.currentTarget).val()
    if species
      @replaceSelectedPokemon(new Pokemon(teambuilder: true, name: species))
    else
      @replaceSelectedPokemon(new NullPokemon())

  changeForme: (e) =>
    $forme = $(e.currentTarget)
    pokemon = @getSelectedPokemon()
    pokemon.set('forme', $forme.val())
    # Forme changes may have different abilities, so we have to change this.
    pokemon.set('ability', pokemon.getAbilities()[0])

  changeNature: (e) =>
    $list = $(e.currentTarget)
    @getSelectedPokemon().set("nature", $list.val())

  changeAbility: (e) =>
    $list = $(e.currentTarget)
    @getSelectedPokemon().set("ability", $list.val())

  changeItem: (e) =>
    $list = $(e.currentTarget)
    @getSelectedPokemon().set("item", $list.val())

  changeGender: (e) =>
    $list = $(e.currentTarget)
    @getSelectedPokemon().set("gender", $list.val())

  changeLevel: (e) =>
    $input = $(e.currentTarget)
    value = parseInt($input.val())
    value = 100  if isNaN(value) || value > 100
    value = 1  if value < 1
    $input.val(value)
    @getSelectedPokemon().set("level", value)

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

  focusEv: (e) =>
    $input = $(e.currentTarget)
    value = parseInt($input.val())
    $input.val("")  if value == 0

  changeEv: (e) =>
    # todo: make changeIv and changeEv DRY
    $input = $(e.currentTarget)
    stat = $input.data("stat")
    value = parseInt($input.val())
    value = 252  if value > 252
    value = 0  if isNaN(value) || value < 0

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

  keydownMoves: (e) =>
    $input = $(e.currentTarget)
    $table = @getPokemonView().find('.table-moves')
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
        # We defer since $input may not have updated yet
        _.defer =>
          return  unless $input.is(":focus")
          moveName = $input.val()
          @filterMovesBy(moveName)

  filterMovesBy: (moveName) =>
    moveName = moveName.replace(/\s+/g, "")
    $table = @getPokemonView().find('.table-moves')
    $allMoves = $table.find('tbody tr')
    moveRegex = new RegExp(moveName, "i")
    $moves = $allMoves.filter ->
      $move = $(this)
      moveName = $move.data('move-search-id')
      moveRegex.test(moveName)
    $table.addClass('hidden')
    $moves.removeClass('hidden')
    $allMoves.not($moves).addClass('hidden')
    $allMoves.removeClass('active')
    $moves.first().addClass('active')
    $table.removeClass('hidden')

  # Prevents the blurMoves event from activating for the duration of
  # the remaining javascript events. This allows the click event to not fire
  # the blur event.
  preventBlurMoves: (e) =>
    @_preventBlur = true
    _.defer =>
      @_preventBlur = false

  blurMoves: (e) =>
    $input = $(e.currentTarget)
    if @_preventBlur
      $view = @getPokemonView()
      previousScrollPosition = $view.scrollTop()
      $input.focus()
      e.preventDefault()
      $view.scrollTop(previousScrollPosition) # prevent scroll from refocus
      return

    $selectedMove = @$selectedMove()
    moveName = $selectedMove.data('move-id')

    # Remove filtering and row selection
    @filterMovesBy("")
    $(".table-moves .active").removeClass("active")

    if $input.val().length == 0
      @recordMoves()
    else
      @insertMove($input, moveName)

  clickMoveName: (e) =>
    $this = $(e.currentTarget)
    moveName = $this.data('move-id')
    $moves = @getPokemonView().find('.selected_moves')
    $input = $moves.find('input:focus').first()
    $input = $moves.find('input').first()  if $input.length == 0
    return  if $input.length == 0
    @insertMove($input, moveName)

  insertMove: ($input, moveName) =>
    $view = @getPokemonView()
    currentScrollPosition = $view.scrollTop()

    @preventBlurMoves()
    return  if !@buttonify($input, moveName)
    $moves = @getPokemonView().find('.selected_moves')
    $firstInput = $moves.find('input').first()
    if $firstInput.length > 0
      $firstInput.focus()
      $view.scrollTop(currentScrollPosition)
    else
      $view.scrollTop(0)
    @recordMoves()

  recordMoves: =>
    movesArray = []
    $moves = @getPokemonView().find('.selected_moves')
    $moves.find('.move-button').each ->
      moveName = $(this).text().trim()
      if moveName != ""
        movesArray.push(moveName)
    @getSelectedPokemon().set("moves", movesArray)

  $selectedMove: =>
    $table = @getPokemonView().find('.table-moves')
    $allMoves = $table.find('tbody tr')
    $allMoves.filter('.active').first()

  clickSelectedMove: (e) =>
    $this = $(e.currentTarget)
    $input = $("<input type='text' value='#{$this.text()}'/>")
    $this.replaceWith($input)
    $input.focus()

    # Set the current move row to active
    $(".table-moves tr[data-move-id='#{$this.text()}']").addClass("active")

  buttonify: ($input, moveName) =>
    return false  if moveName not of @moveData
    
    # The blur event may have been cancelled, so when removing the input also
    # remove the filter
    if $input.is(":focus")
      @filterMovesBy("")
      $(".table-moves .active").removeClass("active")

    type = @moveData[moveName].type.toLowerCase()
    $input.replaceWith("""<div class="button move-button #{type}">#{moveName}</div>""")
    return true

  setSelectedPokemonIndex: (index) =>
    pokemon = @getSelectedTeam().at(index)
    @selectedPokemon = index
    
    # Render the pokemon
    @renderPokemon(pokemon)

    # Set the correct list item to active
    @$(".navigation li").removeClass("active")
    @$(".navigation li").eq(index).addClass("active")

  getSelectedPokemon: =>
    @getSelectedTeam().at(@selectedPokemon)

  replaceSelectedPokemon: (newPokemon) =>
    team = @getSelectedTeam()
    team.remove(team.at(@selectedPokemon))
    team.add(newPokemon, at: @selectedPokemon)

  setSelectedTeamIndex: (index) =>
    @selectedTeam = index
    @renderTeam()

  getSelectedTeam: =>
    @teams[@selectedTeam]

  getPokemonView: () =>
    @$(".pokemon_edit")

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
    @generationChanged(team.generation || DEFAULT_GENERATION)
    @renderGeneration()
    @renderPokemonList()
    @renderPBV()
    @setSelectedPokemonIndex(@selectedPokemon)
    @$('.team_name').text(team.getName())
    @$('.display_teams').addClass('hidden')
    @$('.display_pokemon').removeClass('hidden')

  renderPokemonList: =>
    team = @getSelectedTeam()
    $pokemon_list = @$(".pokemon_list").empty()
    $pokemon_list.html @pokemonListTemplate(window: window, pokemonList: team.models)
    $pokemon_list.find("li[data-pokemon-index=#{@selectedPokemon}]").addClass("active")

    # NOTE: this isn't be used, and just amounts to hiding the button, however
    # we may re-enable this functionality in the future
    # Hide add pokemon if there's 6 pokemon
    if team.length < 6
      @$(".add_pokemon").show()
    else
      @$(".add_pokemon").hide()

  renderPokemon: (pokemon) =>
    $view = @getPokemonView()

    # Render it for the first time if there's nothing inside
    if $view.children().length == 0
      $view.html @editTemplate(window: window, speciesList: @speciesList, itemList: @itemList, pokemon: pokemon)
      $view.find(".species_list").select2(placeholder: "Empty", allowClear: true) # nice dropdown menu

    @renderSpecies(pokemon)
    @renderNonStats(pokemon)
    @renderStats(pokemon)
    @renderMoves(pokemon)
    @renderPBV(pokemon)

    # Disable entering values if this is a NullPokemon
    $view.find("input, select").not(".species_list").prop("disabled", pokemon.isNull)

    return this

  renderPBV: (pokemon) =>
    if pokemon
      individualPBV = pokemon.getPBV()
      $view = @getPokemonView()
      $listItem = @$(".pokemon_list li[data-pokemon-cid=#{pokemon.cid}]")
      $view.find(".individual-pbv").text(individualPBV)
      $listItem.find(".pbv-value").text(individualPBV)

    totalPBV = @getSelectedTeam().getPBV()
    maxPBV = 1000 # temporary

    @$(".total-pbv").text(totalPBV)
    if totalPBV > maxPBV
      @$(".total-pbv").addClass("red")
    else
      @$(".total-pbv").removeClass("red")

  renderGeneration: =>
    generation = @getSelectedTeam().generation || DEFAULT_GENERATION
    text = @$(".change-gen-dropdown a[data-generation='#{generation}']").text()
    @$(".current-generation").text(text)

  renderImportTeamModal: =>
    # Add the import team modal if it doesn't exist
    if $('#import-team-modal').length == 0
      $('body').append(@importTemplate())
      $modal = $('#import-team-modal')
      $modal.on 'click', '.import-team-submit', (e) =>
        teamString = $modal.find('.imported-team').val()
        pokemonJSON = PokeBattle.parseTeam(teamString)
        errors = @validateImportedTeam(pokemonJSON)
        if errors.length > 0
          listErrors = errors.map((e) -> "<li>#{e}</li>").join('')
          $errors = $modal.find('.form-errors')
          $errors.html("<ul>#{listErrors}</ul>").removeClass('hidden')
        else
          @addNewTeam(PokeBattle.jsonToTeam(pokemon: pokemonJSON))
          $modal.find('.imported-team').val("")
          $modal.modal('hide')
        return false

    $modal = $('#import-team-modal')
    $modal.modal('show')
    $modal.find('textarea, input').first().focus()

  renderSpecies: (pokemon) =>
    $view = @getPokemonView()

    $view.find(".species_list").select2('val', pokemon.get("name"))
    html = if pokemon.isNull then "" else @speciesTemplate(window: window, pokemon: pokemon)
    $view.find(".species-info").html(html)

  renderNonStats: (pokemon) =>
    $nonStats = @getPokemonView().find(".non-stats")

    populateSelect = (searchStr, valueTextPairs, selectedValue) ->
      $select = $nonStats.find(searchStr).empty()
      for pair in valueTextPairs
        value = text = pair
        if pair instanceof Array 
          value = pair[0]
          text = pair[1]

        $select.append($("<option>").attr("value", value).text(text))
      $select.val(selectedValue)

    displayedGenders =
      F: "Female"
      M: "Male"

    populateSelect ".selected_ability", pokemon.getAbilities(), pokemon.get("ability")
    populateSelect ".selected_nature", pokemon.getNatures(), pokemon.get("nature")
    $nonStats.find(".selected_item").val(pokemon.get("item"))
    populateSelect ".selected_gender", ([g, displayedGenders[g]] for g in pokemon.getGenders()), pokemon.get("gender")
    $nonStats.find(".selected_level").val(pokemon.get("level"))
    $nonStats.find(".selected_happiness").val(pokemon.get("happiness"))
    $nonStats.find(".selected_shininess").prop("checked", pokemon.get('shiny'))

  renderStats: (pokemon) =>
    $view = @getPokemonView()

    $view.find(".iv-entry").each ->
      $input = $(this)
      stat = $input.data("stat")
      $input.val(pokemon.iv(stat))

    $view.find(".ev-entry").each ->
      $input = $(this)
      stat = $input.data("stat")
      $input.val(pokemon.ev(stat))

    $view.find('.stat-total').each ->
      $this = $(this)
      stat = $this.data("stat")
      $this.text(pokemon.stat(stat))

    $view.find('.total-evs').text("Total EVs: #{pokemon.getTotalEVs()}/510")
    $view.find('.select-hidden-power').val(pokemon.get('hiddenPowerType'))

  renderMoves: (pokemon) =>
    # TODO: Cache the resultant html
    $moveSection = @getPokemonView().find(".moves-section")
    if pokemon.isNull
      $moveSection.html ""
      return

    $moveSection.html @movesTemplate(window: window, pokemon: pokemon)
    $moveSection.find('.selected_moves input').each (i, el) =>
      $this = $(el)
      moveName = $this.val()
      @buttonify($this, moveName)

  validateImportedTeam: (json) =>
    errors = []
    pokemonNames = (pokemon.name  for pokemon in json)
    {SpeciesData} = window.Generations[DEFAULT_GENERATION.toUpperCase()]
    pokemonNames = pokemonNames.filter((name) -> name not of SpeciesData)
    if pokemonNames.length > 0
      errors.push(pokemonNames.map((n) -> "#{n} is not a valid Pokemon.")...)
      return errors
    return errors
