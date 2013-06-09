JST['chat'] = thermos.template (locals) ->
  @div '.user_list', ->
    @p ->
      @strong ".user_count"
    @ul '.users'
  @div '.message_pane', ->
    @div '.messages'
    @div '.chat_input_pane', ->
      @input '.chat_input_send', type: 'button', value: 'Send'
      @div '.chat_input_wrapper', ->
        @input '.chat_input', type: 'text'
