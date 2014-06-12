require '../helpers'

{Battle} = require('../../server/xy/battle')
{Pokemon} = require('../../server/xy/pokemon')
{Status, Attachment} = require('../../server/xy/attachment')
{Conditions} = require '../../shared/conditions'
{Factory} = require '../factory'
should = require 'should'
shared = require '../shared'
{Protocol} = require '../../shared/protocol'

describe 'Mechanics', ->
  describe 'a frozen pokemon', ->
    it "unfreezes if hit by Scald", ->
      shared.create.call(this, gen: 'xy')
      shared.biasRNG.call(this, "next", 'unfreeze chance', 1)  # always stays frozen
      @p1.attach(Status.Freeze)

      @battle.performMove(@p2, @battle.getMove('Scald'))
      @p1.has(Status.Freeze).should.be.false
