class @UserList extends Backbone.Collection
  model: User

  comparator: (a, b) =>
    aAuthority = a.get('authority')
    bAuthority = b.get('authority')
    aName = "#{a.id}".toLowerCase()
    bName = "#{b.id}".toLowerCase()
    if aAuthority < bAuthority      then  1
    else if aAuthority > bAuthority then -1
    else if aName < bName           then -1
    else if aName > bName           then  1
    else                                  0

  initialize: =>
