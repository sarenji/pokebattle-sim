{Attachment, Status} = require('../../server/xy/attachment')
{Battle} = require('../../server/xy/battle')
{Pokemon} = require('../../server/xy/pokemon')
{Weather} = require('../../server/xy/weather')
{Move} = require('../../server/xy/move')
util = require '../../server/xy/util'
{Protocol} = require '../../shared/protocol'
{Factory} = require '../factory'
should = require 'should'
{_} = require 'underscore'
shared = require '../shared'

require '../helpers'

describe "XY Moves:", ->
  describe "Dragon Pulse", ->
    it "has 85 base power now", ->
      shared.create.call(this, gen: 'xy')
      @battle.getMove('Dragon Pulse').power.should.equal(85)
