AuthorityMap =
  "1": ""
  "2": "+"
  "3": "%"
  "4": "@"
  "5": "~"

class @User extends Backbone.Model
  initialize: (attributes) =>

  getDisplayName: =>
    authorityString = AuthorityMap[@get('authority')] ? ""
    "#{authorityString}#{@get('name')}"

  isAlt: =>
    @get('isAlt')

  profileUrl: =>
    "//pokebattle.com/users/#{@id}/#{slugify(@get('name'))}"

slugify = (str) ->
  str.toLowerCase().replace(/[^a-z0-9]/g, '-').replace(/\-{2,}/g, '-')
