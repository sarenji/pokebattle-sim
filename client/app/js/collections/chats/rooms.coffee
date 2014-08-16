class @Rooms extends Backbone.Collection
  model: Room

  # Delegate room events to every single room in this collection.
  for eventName in Room::EVENTS
    do (eventName) =>
      this::[eventName] = (args...) ->
        @each (room) ->
          room[eventName].apply(room, args)
