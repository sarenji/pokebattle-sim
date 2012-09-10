JST['chat'] = thermos.template (locals) ->
  @ul '.user_list'
  @div '.message_pane', ->
    @div '.messages'
    @input '.chat_input', type: 'text'
