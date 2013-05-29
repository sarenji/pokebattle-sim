JST['chat'] = thermos.template (locals) ->
  @div '.user_list', ->
    @p ->
      @strong ".user_count"
    @ul '.users'
  @div '.message_pane', ->
    @div '.messages'
    @input '.chat_input', type: 'text'
