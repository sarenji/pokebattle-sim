AuthorityMap =
  "1": ""
  "2": "+"
  "3": "%"
  "4": "@"
  "5": "~"

class @User extends Backbone.Model
  initialize: (attributes) =>

  getDisplayName: =>
    authorityString = AuthorityMap[@get('authority')]
    "#{authorityString}#{@get('id')}"
