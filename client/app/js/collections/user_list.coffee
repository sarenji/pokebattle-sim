class @UserList extends Backbone.Collection
  model: User

  comparator: (a, b) =>
    aName = a.id
    bName = b.id
    if aName < bName      then -1
    else if aName > bName then  1
    else                        0

  initialize: =>
