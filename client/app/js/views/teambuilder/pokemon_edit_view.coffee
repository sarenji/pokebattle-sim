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
      @selectize?.setValue(value)

setSelectizeDisabled = ($element, disabled) ->
  $element.filter(".selectized").each ->
    return  unless @selectize
    if disabled then @selectize.disable() else @selectize.enable()

class @PokemonEditView extends Backbone.View
  editTemplate: JST['teambuilder/pokemon']
  speciesTemplate: JST['teambuilder/species']
  nonStatsTemplate: JST['teambuilder/non_stats']
  movesTemplate: JST['teambuilder/moves']

  events:
    'change .species_list': 'changeSpecies'
    'change .selected_nickname': 'changeNickname'
    'click .selected_shininess': 'changeShiny'
    'click .selected_happiness': 'changeHappiness'
    'change .selected-forme': 'changeForme'
    'change .selected-mega': 'changeMega'
    'change .selected_nature': 'changeNature'
    'change .selected_ability': 'changeAbility'
    'change .selected_item': 'changeItem'
    'change .selected_gender': 'changeGender'
    'change .selected_level': 'changeLevel'
    'change .iv-entry': 'changeIv'
    'focus .ev-entry': 'focusEv'
    'blur .ev-entry': 'changeEv'
    'change .ev-entry': 'changeEv'
    'input .ev-entry[type=range]': 'changeEv'
    'mouseup .ev-entry[type=range]': 'mouseupEVSlider'
    'click .ev-lock': 'toggleEVLocked'
    'change .select-hidden-power': 'changeHiddenPower'
    'keydown .selected_moves input': 'keydownMoves'
    'blur .selected_moves input': 'blurMoves'
    'click .table-moves tbody tr': 'clickMoveName'
    'mousedown .table-moves': 'preventBlurMoves'
    'click .move-button': 'clickSelectedMove'
    'click .move-button .close': 'removeSelectedMove'

  initialize: (attributes={}) =>
    @onPokemonChange = attributes.onPokemonChange

  setFormat: (format) =>
    format = Formats[format] || Formats[DEFAULT_FORMAT]
    @setGeneration(format.generation)
    # TODO: Set PBV limit based on conditions

  setGeneration: (generation) =>
    @generation = window.Generations[generation.toUpperCase()]
    {MoveData, SpeciesData, ItemData} = @generation
    @moveData = MoveData
    @speciesList = (species for species, data of SpeciesData)
    # TODO: filter irrelevant items
    @itemList = (_(itemName for itemName, data of ItemData).sort())

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

  # Returns true if Evs are locked to 510 maximum
  isEVLocked: =>
    $('.ev-lock span:visible').data('locked')

  toggleEVLocked: =>
    $('.ev-lock span').toggle()

  changeSpecies: (e) =>
    return  if not @onPokemonChange
    species = $(e.currentTarget).val()
    @pokemon = if species
        new Pokemon(teambuilder: true, species: species)
      else
        new NullPokemon()
    @onPokemonChange(@pokemon)

  changeNickname: (e) =>
    $input = $(e.currentTarget)
    @pokemon.set("name", $input.val())

  changeShiny: (e) =>
    $switch = $(e.currentTarget).toggleClass("selected")
    @pokemon.set("shiny", $switch.is(".selected"))

  changeHappiness: (e) =>
    $switch = $(e.currentTarget).toggleClass("selected")
    happiness = if $switch.is(".selected") then 0 else 100
    @pokemon.set("happiness", happiness)

  changeForme: (e) =>
    $forme = $(e.currentTarget)
    @pokemon.set('forme', $forme.val())
    # Forme changes may have different abilities, so we have to change this.
    @pokemon.set('ability', @pokemon.getAbilities()[0])

  changeMega: (e) =>
    mega = $(e.currentTarget).val()
    if mega
      for itemName, data of @generation.ItemData
        if data.mega && data.mega[0] == @pokemon.get('species') && data.mega[1] == mega
          @pokemon.set('item', itemName)
          console.log(itemName)
          break
    else
      # Converting to non-mega. Remove the megastone if any
      item = @generation.ItemData[@pokemon.get('item')]
      if item?.mega?[0] == @pokemon.get('species')
        @pokemon.set('item', null)

    # update the item dropdown (note: somewhat inefficient as it updates multiple dropdowns)
    @renderNonStats()

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
    value = parseInt($input.val(), 10)
    value = 100  if isNaN(value) || value > 100
    value = 1  if value < 1
    $input.val(value)
    @pokemon.set("level", value)

  changeIv: (e) =>
    # todo: make changeIv and changeEv DRY
    $input = $(e.currentTarget)
    stat = $input.data("stat")
    value = parseInt($input.val(), 10)
    if isNaN(value) || value > 31 || value < 0
      value = 31

    @pokemon.setIv(stat, value)

  focusEv: (e) =>
    $input = $(e.currentTarget)
    return  if $input.is("[type=range]")
    value = parseInt($input.val(), 10)
    $input.val("")  if value == 0

  changeEv: (e) =>
    $input = $(e.currentTarget)
    stat = $input.data("stat")
    value = parseInt($input.val(), 10)
    value = 0  if isNaN(value) 
    value = 252  if value > 252

    if @isEVLocked()
      availableEVs = 510 - @pokemon.getTotalEVs(exclude: stat)
      value = availableEVs  if value > availableEVs

    value = 0  if value < 0
    value = @pokemon.setEv(stat, value)
    $input.val(value)  if not $input.is("[type=range]")

  mouseupEVSlider: (e) =>
    $slider = $(e.currentTarget)
    $input = @$(".ev-entry[data-stat=#{$slider.data('stat')}]").not($slider)
    $slider.val $input.val()

  changeHiddenPower: (e) =>
    $input = $(e.currentTarget)
    type = $input.val()
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

    # If preventBlur is set, then perform a refocus (undo the blur)
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
    @$(".table-moves .active").removeClass("active")

    if $input.val().length == 0
      @recordMoves()
    else
      @insertMove($input, moveName)

  clickMoveName: (e) =>
    $this = $(e.currentTarget)
    moveName = $this.data('move-id')

    if moveName in @getSelectedMoves()
      @removeMove(moveName)
    else
      @insertMove(moveName)

  insertMove: (moveName, $input) =>
    if !$input
      $moves = @$el.find('.selected_moves')
      $input = $moves.find('input:focus').first()
      $input = $moves.find('input').first()  if $input.length == 0
      return  if $input.length == 0

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

  removeMove: (moveName) =>
    indices = (i for move, i in @getAllSelectedMoves() when move == moveName)

    for idx in indices
      $input = @$('.selected_moves .move-slot').eq(idx).children()
      $input = @reverseButtonify($input)  if $input.is('.move-button')
      $input.val("")

  # Returns the moves currently selected in the teambuilder (Not the Pokemon)
  getSelectedMoves: =>
    _(@getAllSelectedMoves()).compact()

  # Returns the contents of each selected move, even if that selected move is null
  getAllSelectedMoves: =>
    movesArray = []
    $moves = @$el.find('.selected_moves .move-slot')
    $moves.each ->
      moveName = $(this).find(".move-button span").text().trim()
      movesArray.push(moveName)
    movesArray

  recordMoves: =>
    @pokemon.set("moves", @getSelectedMoves())

  $selectedMove: =>
    $table = @$el.find('.table-moves')
    $allMoves = $table.find('tbody tr')
    $allMoves.filter('.active').first()

  clickSelectedMove: (e) =>
    $this = $(e.currentTarget)
    moveName = @reverseButtonify($this).focus().select().val()

    # Set the current move row to active
    $(".table-moves tr[data-move-id='#{moveName}']").addClass("active")

  removeSelectedMove: (e) =>
    $this = $(e.currentTarget).parent()
    @reverseButtonify($this).val('').focus()
    e.stopPropagation()

  buttonify: ($input, moveName) =>
    return false  if moveName not of @moveData

    # When removing the input also remove the filter
    # Normally this is done by blurMoves,
    # but the blur event may have been prevented by preventBlurMoves 
    if $input.is(":focus")
      @filterMovesBy("")
      @$(".table-moves .active").removeClass("active")

    type = @moveData[moveName].type.toLowerCase()
    $input.replaceWith("""
      <div class="button move-button #{type}"><span>#{moveName}</span><div class='close'>&times;</div></div>
    """)

    @updateSelectedMoveStyles()

    return true

  reverseButtonify: ($button) =>
    moveName = $button.find('span').text()
    $input = $("<input type='text' value='#{moveName}'/>")
    $button.replaceWith($input)
    @updateSelectedMoveStyles()
    $input

  keydownMoves: (e) =>
    $input = $(e.currentTarget)
    $table = @$el.find('.table-moves')
    $allMoves = $table.find('tbody tr')
    switch e.which
      when 13  # [Enter]; we're selecting the active move.
        $activeMove = @$selectedMove()
        @insertMove($activeMove.data('move-id'))
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
    @$el.html @editTemplate(window: window, speciesList: @speciesList, itemList: @itemList)
    attachSelectize(@$el.find(".species_list"),
      render:
        option: (item, escape) =>
          pbv = PokeBattle.PBV.determinePBV(@generation, species: item.value)
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
    $elements = @$el.find("input, select").not(".species input, .species select")
    $elements.prop("disabled", @pokemon.isNull)
    setSelectizeDisabled($elements, @pokemon.isNull)

    return this

  renderPBV: =>
    individualPBV = @pokemon.getPBV()
    @$(".individual-pbv").text(individualPBV)

    team = @pokemon.getTeam()
    if team && team.hasPBV()
      pbv = team.getPBV()
      maxPBV = team.getMaxPBV()
      @$(".total-pbv").text(pbv).toggleClass("red", pbv > maxPBV)
      @$(".max-pbv").text(maxPBV)

  renderSpecies: =>
    @disableEventsAndExecute =>
      setSelectizeValue(@$(".species_list"), @pokemon.get("species"))
      html = if @pokemon.isNull then "" else @speciesTemplate(window: window, pokemon: @pokemon)
      @$(".species-info").html(html)
      @$(".selected_shininess").toggleClass("selected", @pokemon.get('shiny') == true)
      @$(".selected_happiness").toggleClass("selected", @pokemon.get("happiness") == 0)

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
      Genderless: "Genderless"

    @disableEventsAndExecute =>
      genders = ([g, displayedGenders[g]] for g in @pokemon.getGenders())
      $nonStats.find(".selected_nickname").val(@pokemon.get("name"))
      populateSelect ".selected_ability", @pokemon.getAbilities(), @pokemon.get("ability")
      populateSelect ".selected_nature", @pokemon.getNatures(), @pokemon.get("nature")
      setSelectizeValue(@$(".selected_item"), @pokemon.get("item"))
      populateSelect ".selected_gender", genders, @pokemon.get("gender")
      $nonStats.find(".selected_level").val(@pokemon.get("level"))

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

  updateSelectedMoveStyles: =>
    @$(".table-moves .selected").removeClass("selected")
    for move in @getSelectedMoves()
      @$(".table-moves tr[data-move-id='#{move}']").addClass("selected")