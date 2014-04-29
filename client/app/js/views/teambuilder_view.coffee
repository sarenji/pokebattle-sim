class @TeambuilderView extends Backbone.View
  template: JST['teambuilder/main']
  teamsTemplate: JST['teambuilder/teams']
  pokemonListTemplate: JST['teambuilder/pokemon_list']
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

    # Teambuild view
    'click .change-gen-dropdown a': 'changeTeamGeneration'
    'blur .team_name': 'blurTeamName'
    'keypress .team_name': 'keypressTeamName'
    'click .go_back': 'goBackToOverview'
    'click .pokemon_list li': 'clickPokemon'
    'click .add_pokemon': 'addNewPokemonEvent'
    'click .save_team': 'saveTeam'

  initialize: (attributes) =>
    @selectedPokemon = 0
    @selectedTeam = null

    @render()

    @pokemonEditView = new PokemonEditView(
      el: @$('.pokemon_edit')
      onPokemonChange: (newPokemon) =>
        team = @getSelectedTeam()
        team.replace(@selectedPokemon, newPokemon)
        @renderPBV()
    )

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

  changeTeamGeneration: (e) =>
    $link = $(e.currentTarget)
    generation = $link.data('generation')
    team = @getSelectedTeam()
    if generation != team.get('generation')
      team.set('generation', generation)
      @renderTeam()
      @dirty() # renderTeam() removes dirty, so call it again

  setSelectedPokemonIndex: (index) =>
    pokemon = @getSelectedTeam().at(index)
    @selectedPokemon = index
    
    # Render the pokemon
    @pokemonEditView.setPokemon(pokemon)
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

  blurTeamName: =>
    teamName = @$('.team_name').text()
    @getSelectedTeam().set('name', teamName)

  keypressTeamName: (e) =>
    if e.which == 13  # [Enter]
      @$('.team_name').blur()

  goBackToOverview: =>
    if @_dirty
      @resetHeaderButtons()
    @renderTeams()

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

  renderTeams: =>
    @$('.display_teams').html @teamsTemplate(teams: @getAllTeams(), window: window)
    @$('.display_teams').removeClass('hidden')
    @$('.display_pokemon').addClass('hidden')

    $teamList = @$('.teams-list')
    $teamList.sortable().on('drag', ->
      # Fix the placeholder size (TODO: Make this a general easy to apply fix)
      $dragged = $teamList.find('.sortable-dragging')
      $placeholder = $teamList.find('.sortable-placeholder')
      if $dragged && $placeholder && !$placeholder.data('resized')
        $placeholder
          .addClass($dragged.attr('class'))
          .width($dragged.width())
          .height($dragged.height())
          .css("visibility", "hidden")
          .data('resized', true)
    ).bind('sortupdate', (e, ui) ->
      $team = ui.item
      PokeBattle.TeamStore.moveTeam($team.data('id'), $team.index())
    )

    this

  renderTeam: =>
    team = @getSelectedTeam()
    @pokemonEditView.setGeneration(team.get('generation')  || DEFAULT_GENERATION)
    @renderGeneration()
    @renderPokemonList()
    @renderPBV()
    @setSelectedPokemonIndex(@selectedPokemon)
    @$('.team_name').text(team.getName())
    @$('.display_teams').addClass('hidden')
    @$('.display_pokemon').removeClass('hidden')

  renderPokemonList: =>
    team = @getSelectedTeam()
    $navigation = @$(".navigation")
    $navigation.html @pokemonListTemplate(window: window, pokemonList: team.models)
    $navigation.find("li").eq(@selectedPokemon).addClass("active")

    # NOTE: this isn't be used, and just amounts to hiding the button, however
    # we may re-enable this functionality in the future
    # Hide add pokemon if there's 6 pokemon
    if team.length < 6
      @$(".add_pokemon").show()
    else
      @$(".add_pokemon").hide()

    @$(".pokemon_list").sortable().bind('sortupdate', (e, ui) =>
      $pokemonListItem = ui.item
      newIndex = $pokemonListItem.index()

      selectedPokemon = @getSelectedPokemon()
      movedPokemon = team.pokemon.get($pokemonListItem.data('pokemon-cid'))

      team.pokemon.remove(movedPokemon, silent: true)
      team.pokemon.add(movedPokemon, at: newIndex, silent: true)
      @selectedPokemon = @$(".pokemon_list li[data-pokemon-cid=#{selectedPokemon.cid}]").index()
      @dirty()
    )

  renderPokemon: (pokemon) =>
    @pokemonEditView.setPokemon(pokemon)

  renderPBV: (pokemon) =>
    if pokemon
      individualPBV = pokemon.getPBV()
      $listItem = @$(".pokemon_list li[data-pokemon-cid=#{pokemon.cid}]")
      $listItem.find(".pbv-value").text(individualPBV)
    
    totalPBV = @getSelectedTeam().getPBV()
    @pokemonEditView.setTeamPBV(totalPBV)
    @pokemonEditView.renderPBV()

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

  validateImportedTeam: (json) =>
    errors = []
    pokemonNames = (pokemon.name  for pokemon in json)
    {SpeciesData} = window.Generations[DEFAULT_GENERATION.toUpperCase()]
    pokemonNames = pokemonNames.filter((name) -> name not of SpeciesData)
    if pokemonNames.length > 0
      errors.push(pokemonNames.map((n) -> "#{n} is not a valid Pokemon.")...)
      return errors
    return errors
