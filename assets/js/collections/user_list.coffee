class @UserList extends Backbone.Collection
  model: User

  comparator: (a, b) =>
    aName = a.get('name')
    bName = b.get('name')
    if aName < bName      then -1
    else if aName > bName then  1
    else                        0

  initialize: =>
