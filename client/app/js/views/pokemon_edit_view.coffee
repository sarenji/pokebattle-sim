isMobileOrAndroid = ->
  return true if /Mobile/i.test(window.navigator.userAgent)
  return true if /Android/i.test(window.navigator.userAgent)
  return false

# helper which attaches selectize
attachSelectize = ($element, options) ->
  # Block selectize on mobile and all android operating systems (All androids are blocked due to a bug)
  return  if isMobileOrAndroid()
  $element.selectize(options)

setSelectizeValue = ($element, value) ->
  if isMobileOrAndroid()
    $element.val(value)
  else
    $element.each ->
      this.selectize?.setValue(value)

class @PokemonEditView extends Backbone.View
  editTemplate: JST['teambuilder/pokemon']
  speciesTemplate: JST['teambuilder/species']
  nonStatsTemplate: JST['teambuilder/non_stats']
  movesTemplate: JST['teambuilder/moves']

  events:
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
    'click .move-button .close': 'removeSelectedMove'

  initialize: (attributes={}) =>
    @onPokemonChange = attributes.onPokemonChange

  setGeneration: (generation) =>
    @generation = window.Generations[generation.toUpperCase()]
    {MoveData, SpeciesData, ItemData} = @generation
    @moveData = MoveData
    @speciesList = (name for name, data of SpeciesData)
    # TODO: filter irrelevant items
    @itemList = (_(name for name, data of ItemData).sort())
    
    @render()

  setPokemon: (pokemon) =>
    # Stop listening for change events on the previously set pokemon
    @stopListening(@pokemon)  if @pokemon
    
    @pokemon = pokemon
    @listenTo(pokemon, 'change:level', @renderStats)
    @listenTo(pokemon, 'change:ivs', @renderStats)
    @listenTo(pokemon, 'change:evs', @renderStats)
    @listenTo(pokemon, 'change:nature', @renderStats)
    @listenTo(pokemon, 'change:hiddenPowerType', @renderStats)
    @listenTo(pokemon, 'change:shiny', @renderSpecies)

    @renderPokemon()

  setTeamPBV: (pbv) =>
    @teamPBV = pbv

  changeSpecies: (e) =>
    return  if not @onPokemonChange
    species = $(e.currentTarget).val()
    @pokemon = if species then new Pokemon(teambuilder: true, name: species) else new NullPokemon()
    @onPokemonChange(@pokemon)

  changeForme: (e) =>
    $forme = $(e.currentTarget)
    @pokemon.set('forme', $forme.val())
    # Forme changes may have different abilities, so we have to change this.
    @pokemon.set('ability', @pokemon.getAbilities()[0])

  changeNature: (e) =>
    $list = $(e.currentTarget)
    @pokemon.set("nature", $list.val())

  changeAbility: (e) =>
    $list = $(e.currentTarget)
    @pokemon.set("ability", $list.val())

  changeItem: (e) =>
    $list = $(e.currentTarget)
    @pokemon.set("item", $list.val())

  changeGender: (e) =>
    $list = $(e.currentTarget)
    @pokemon.set("gender", $list.val())

  changeLevel: (e) =>
    $input = $(e.currentTarget)
    value = parseInt($input.val())
    value = 100  if isNaN(value) || value > 100
    value = 1  if value < 1
    $input.val(value)
    @pokemon.set("level", value)

  changeHappiness: (e) =>
    $input = $(e.currentTarget)
    value = parseInt($input.val())
    value = 100  if isNaN(value) || value > 100
    value = 0  if value < 0
    $input.val(value)
    @pokemon.set("happiness", value)

  changeShiny: (e) =>
    $checkbox = $(e.currentTarget).toggleClass("selected")
    @pokemon.set("shiny", $checkbox.is(".selected"))

  changeIv: (e) =>
    # todo: make changeIv and changeEv DRY
    $input = $(e.currentTarget)
    stat = $input.data("stat")
    value = parseInt($input.val())
    if isNaN(value) || value > 31 || value < 0
      value = 31

    @pokemon = @pokemon
    @pokemon.setIv(stat, value)

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

    value = @pokemon.setEv(stat, value)
    $input.val(value)  if not $input.is("[type=range]")

  changeHiddenPower: (e) =>
    $input = $(e.currentTarget)
    type = $input.val()
    @pokemon = @pokemon
    @pokemon.set('hiddenPowerType', type.toLowerCase())

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
      previousScrollPosition = @$el.scrollTop()
      $input.focus()
      e.preventDefault()
      @$el.scrollTop(previousScrollPosition) # prevent scroll from refocus
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
    $moves = @$el.find('.selected_moves')
    $input = $moves.find('input:focus').first()
    $input = $moves.find('input').first()  if $input.length == 0
    return  if $input.length == 0
    @insertMove($input, moveName)

  insertMove: ($input, moveName) =>
    currentScrollPosition = @$el.scrollTop()

    @preventBlurMoves()
    return  if !@buttonify($input, moveName)
    $moves = @$el.find('.selected_moves')
    $firstInput = $moves.find('input').first()
    if $firstInput.length > 0
      $firstInput.focus()
      @$el.scrollTop(currentScrollPosition)
    else
      @$el.scrollTop(0)
    @recordMoves()

  recordMoves: =>
    movesArray = []
    $moves = @$el.find('.selected_moves')
    $moves.find('.move-button').each ->
      moveName = $(this).text().trim()
      if moveName != ""
        movesArray.push(moveName)
    @pokemon.set("moves", movesArray)

  $selectedMove: =>
    $table = @$el.find('.table-moves')
    $allMoves = $table.find('tbody tr')
    $allMoves.filter('.active').first()

  clickSelectedMove: (e) =>
    $this = $(e.currentTarget)
    moveName = $this.find('span').text()
    $input = $("<input type='text' value='#{moveName}'/>")
    $this.replaceWith($input)
    $input.focus()

    # Set the current move row to active
    $(".table-moves tr[data-move-id='#{moveName}']").addClass("active")

  removeSelectedMove: (e) =>
    $this = $(e.currentTarget).parent()
    $input = $("<input type='text'/>")
    $this.replaceWith($input)
    $input.focus()
    e.stopPropagation()

  buttonify: ($input, moveName) =>
    return false  if moveName not of @moveData
    
    # The blur event may have been cancelled, so when removing the input also
    # remove the filter
    if $input.is(":focus")
      @filterMovesBy("")
      $(".table-moves .active").removeClass("active")

    type = @moveData[moveName].type.toLowerCase()
    $input.replaceWith("""
      <div class="button move-button #{type}"><span>#{moveName}</span><div class='close'>&times;</div></div>
    """)
    return true

  keydownMoves: (e) =>
    $input = $(e.currentTarget)
    $table = @$el.find('.table-moves')
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
    $table = @$el.find('.table-moves')
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

  disableEventsAndExecute: (callback) =>
    isOutermost = !@_eventsDisabled

    @_eventsDisabled = true
    @undelegateEvents()  if isOutermost # disable events
    callback()
    @delegateEvents()  if isOutermost
    @_eventsDisabled = false  if isOutermost

  render: =>
    @$el.html @editTemplate(window: window, speciesList: @speciesList, itemList: @itemList, pokemon: @pokemon)
    attachSelectize(@$el.find(".species_list"),
      render:
        option: (item, escape) =>
          pbv = PokeBattle.PBV.determinePBV(@generation, name: item.value)
          return "<div class='clearfix'>#{item.text}<div class='pbv'>#{pbv}</div></div>"
    )
    attachSelectize(@$el.find(".selected_item"))
    return this

  renderPokemon: =>
    @renderSpecies()
    @renderNonStats()
    @renderStats()
    @renderMoves()
    @renderPBV()

    # Disable entering values if this is a NullPokemon
    @$el.find("input, select")
      .not(".species input, .species select")
      .prop("disabled", @pokemon.isNull)

    return this

  renderPBV: =>
    if @pokemon
      individualPBV = @pokemon.getPBV()
      @$(".individual-pbv").text(individualPBV)

    if @teamPBV
      maxPBV = 1000 # temporary
      @$(".total-pbv").text(@teamPBV).toggleClass("red", @teamPBV > maxPBV)

  renderSpecies: =>
    @disableEventsAndExecute =>
      setSelectizeValue(@$(".species_list"), @pokemon.get("name"))
      html = if @pokemon.isNull then "" else @speciesTemplate(window: window, pokemon: @pokemon)
      @$(".species-info").html(html)
      @$(".selected_shininess").toggleClass("selected", @pokemon.get('shiny') == true)

  renderNonStats: =>
    $nonStats = @$el.find(".non-stats")

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

    @disableEventsAndExecute =>
      populateSelect ".selected_ability", @pokemon.getAbilities(), @pokemon.get("ability")
      populateSelect ".selected_nature", @pokemon.getNatures(), @pokemon.get("nature")
      setSelectizeValue(@$(".selected_item"), @pokemon.get("item"))
      populateSelect ".selected_gender", ([g, displayedGenders[g]] for g in @pokemon.getGenders()), @pokemon.get("gender")
      $nonStats.find(".selected_level").val(@pokemon.get("level"))
      $nonStats.find(".selected_happiness").val(@pokemon.get("happiness"))

  renderStats: =>
    pokemon = @pokemon

    @$(".iv-entry").each ->
      $input = $(this)
      stat = $input.data("stat")
      $input.val(pokemon.iv(stat))

    @$(".ev-entry").each ->
      return  if $(this).is(":focus")
      $input = $(this)
      stat = $input.data("stat")
      $input.val(pokemon.ev(stat))

    @$('.base-stat').each ->
      $this = $(this)
      stat = $this.data("stat")
      $this.text(pokemon.base(stat))

    @$('.stat-total').each ->
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

    remainingEvs = 508 - @pokemon.getTotalEVs()
    @$('.remaining-evs-amount')
      .text(remainingEvs)
      .toggleClass("over-limit", remainingEvs < 0)
    
    @$('.select-hidden-power').val(@pokemon.get('hiddenPowerType'))

  renderMoves: =>
    # TODO: Cache the resultant html
    $moveSection = @$el.find(".moves-section")
    if @pokemon.isNull
      $moveSection.html ""
      return

    $moveSection.html @movesTemplate(window: window, pokemon: @pokemon)
    $moveSection.find('.selected_moves input').each (i, el) =>
      $this = $(el)
      moveName = $this.val()
      @buttonify($this, moveName)
