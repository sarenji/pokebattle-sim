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
    'click .save_team': 'saveTeam'
    'change .species_list': 'changeSpecies'
    'change .selected-forme': 'changeForme'
    'change .selected_nature': 'changeNature'
    'change .selected_ability': 'changeAbility'
    'change .selected_item': 'changeItem'
    'change .selected_gender': 'changeGender'
    'change .selected_level': 'changeLevel'
    'change .selected_happiness': 'changeHappiness'
    'click .selected_shininess': 'changeShiny'
    'change .iv-entry': 'changeIv'
    'focus .ev-entry': 'focusEv'
    'blur .ev-entry': 'changeEv'
    'change .ev-entry': 'changeEv'
    'input .ev-entry[type=range]': 'changeEv'  # fix for firefox
    'change .select-hidden-power': 'changeHiddenPower'
    'keydown .selected_moves input': 'keydownMoves'
    'blur .selected_moves input': 'blurMoves'
    'click .table-moves tbody tr': 'clickMoveName'
    'mousedown .table-moves': 'preventBlurMoves'
    'click .move-button': 'clickSelectedMove'

  initialize: (attributes) =>
    @selectedPokemon = 0
    @selectedTeam = null
    @render()

  clickTeam: (e) =>
    $team = $(e.currentTarget)
    team = PokeBattle.TeamStore.get($team.data('id'))
    @setSelectedTeam(team)

  clickPokemon: (e) =>
    $listItem = $(e.currentTarget)
    index = @$('.pokemon_list li').index($listItem)
    @setSelectedPokemonIndex(index)

  attachEventsToTeam: (team) =>
    return  if team.attachedTeambuildEvents

    @listenTo(team.pokemon, 'add', @renderPokemon)
    @listenTo(team.pokemon, 'change:level', @renderStats)
    @listenTo(team.pokemon, 'change:ivs', @renderStats)
    @listenTo(team.pokemon, 'change:evs', @renderStats)
    @listenTo(team.pokemon, 'change:nature', @renderStats)
    @listenTo(team.pokemon, 'change:hiddenPowerType', @renderStats)
    @listenTo(team.pokemon, 'change:shiny', @renderPokemon)

    # Todo: Make this perform better
    @listenTo(team.pokemon, 'change:name change:forme', (pokemon) =>
      @renderPokemonList()
      @renderPokemon(pokemon)
    )

    @listenTo(team.pokemon, 'add remove', @renderPokemonList)
    @listenTo(team.pokemon, 'reset', @renderTeam)
    @listenTo(team.pokemon, 'change reset add remove', @dirty)
    @listenTo(team.pokemon, 'change reset add remove', @renderPBV)

    @listenTo(team, 'change', @dirty)

    # A temporary flag to attach until the teambuilder view is refactored
    team.attachedTeambuildEvents = true

  addEmptyPokemon: (team) =>
    team.pokemon.add(new NullPokemon())

  addNewTeamEvent: (e) =>
    @addNewTeam()

  addNewTeam: (team) =>
    team ||= new Team()
    @addEmptyPokemon(team)  while team.length < 6
    @attachEventsToTeam(team)
    team.save()
    @renderTeams()

  cloneTeam: (e) =>
    $team = $(e.currentTarget).closest('.select-team')
    id = $team.data('id')
    @getTeam(id).clone().set("id", null).save()
    @renderTeams()
    return false

  deleteTeam: (e) =>
    return false  if !confirm("Do you really want to delete this team?")
    $team = $(e.currentTarget).closest('.select-team')
    @getTeam($team.data('id')).destroy()
    @renderTeams()
    return false

  exportTeam: (e) =>
    if $('#export-team-modal').length == 0
      $('body').append(@exportTemplate())
    $team = $(e.currentTarget).closest('.select-team')
    id = $team.data('id')
    if not @getTeam(id).hasNonNullPokemon()
      alert("You cannot export empty teams. Please add some pokemon first.")
      return false

    teamJSON = @getTeam(id).toNonNullJSON()
    teamString = PokeBattle.exportTeam(teamJSON.pokemon)

    $modal = $('#export-team-modal')
    $modal.find('.exported-team').val(teamString)
    $modal.modal('show')
    $modal.find('textarea, input').first().focus().select()
    return false

  addNewPokemonEvent: =>
    @addNewPokemon(@getSelectedTeam())

  addNewPokemon: (team) =>
    @addEmptyPokemon(team)
    @$('.pokemon_list li').last().click()

  saveTeam: =>
    @getSelectedTeam().save()
    @resetHeaderButtons()

  changeSpecies: (e) =>
    team = @getSelectedTeam()
    species = $(e.currentTarget).val()

    if species
      team.replace(@selectedPokemon, new Pokemon(teambuilder: true, name: species))
    else
      team.replace(@selectedPokemon, new NullPokemon())

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

  changeHappiness: (e) =>
    $input = $(e.currentTarget)
    value = parseInt($input.val())
    value = 100  if isNaN(value) || value > 100
    value = 0  if value < 0
    $input.val(value)
    @getSelectedPokemon().set("happiness", value)

  changeShiny: (e) =>
    $checkbox = $(e.currentTarget).toggleClass("selected")
    @getSelectedPokemon().set("shiny", $checkbox.is(".selected"))

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
    return  if $input.is("[type=range]")
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
    $input.val(value)  if not $input.is("[type=range]")

  changeHiddenPower: (e) =>
    $input = $(e.currentTarget)
    type = $input.val()
    pokemon = @getSelectedPokemon()
    pokemon.set('hiddenPowerType', type.toLowerCase())

  changeTeamGeneration: (e) =>
    $link = $(e.currentTarget)
    generation = $link.data('generation')
    team = @getSelectedTeam()
    if generation != team.get('generation')
      team.set('generation', generation)
      @renderTeam()
      @dirty() # renderTeam() removes dirty, so call it again

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
    moveName = moveName.replace(/\s+|-/g, "")
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

  setSelectedTeam: (team) =>
    # Duplicate the team, so that changes don't stick until saved
    @selectedTeam = team.clone()
    @selectedTeam.id = team.id
    @selectedPokemon = 0
    @attachEventsToTeam(@selectedTeam)
    @renderTeam()

  getAllTeams: =>
    PokeBattle.TeamStore.models

  getSelectedTeam: =>
    @selectedTeam

  getTeam: (idx) =>
    PokeBattle.TeamStore.get(idx)

  getPokemonView: () =>
    @$(".pokemon_edit")

  blurTeamName: =>
    teamName = @$('.team_name').text()
    @getSelectedTeam().set('name', teamName)

  keypressTeamName: (e) =>
    if e.which == 13  # [Enter]
      @$('.team_name').blur()

  goBackToOverview: =>
    if @_dirty
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
    @$('.display_teams').html @teamsTemplate(teams: @getAllTeams(), window: window)
    @$('.display_teams').removeClass('hidden')
    @$('.display_pokemon').addClass('hidden')

  renderTeam: =>
    team = @getSelectedTeam()
    @generationChanged(team.get('generation')  || DEFAULT_GENERATION)
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
    $view.find("input, select")
      .not(".species_list").not('.select2-input')
      .prop("disabled", pokemon.isNull)

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
    generation = @getSelectedTeam().get("generation") || DEFAULT_GENERATION
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
          team = new Team(pokemon: pokemonJSON, teambuilder: true)
          team.save()
          @addNewTeam(team)
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
    $view.find(".selected_shininess").toggleClass("selected", pokemon.get('shiny') == true)

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

  renderStats: (pokemon) =>
    $view = @getPokemonView()

    $view.find(".iv-entry").each ->
      $input = $(this)
      stat = $input.data("stat")
      $input.val(pokemon.iv(stat))

    $view.find(".ev-entry").each ->
      return  if $(this).is(":focus")
      $input = $(this)
      stat = $input.data("stat")
      $input.val(pokemon.ev(stat))

    $view.find('.base-stat').each ->
      $this = $(this)
      stat = $this.data("stat")
      $this.text(pokemon.base(stat))

    $view.find('.stat-total').each ->
      $this = $(this)
      stat = $this.data("stat")
      $this.text(pokemon.stat(stat))
      $this.removeClass('plus-nature minus-nature')

      if pokemon.natureBoost(stat) > 1
        $this.addClass('plus-nature')
        $this.text($this.text() + '+')

      if pokemon.natureBoost(stat) < 1
        $this.addClass('minus-nature')
        $this.text($this.text() + '-')

    remainingEvs = 508 - pokemon.getTotalEVs()
    $view.find('.remaining-evs-amount')
      .text(remainingEvs)
      .toggleClass("over-limit", remainingEvs < 0)
    
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
