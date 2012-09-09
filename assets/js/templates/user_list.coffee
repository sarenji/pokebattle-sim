JST['user_list'] = thermos.template (locals) ->
  locals.userList.each (user) =>
    @li -> user.get('name')
