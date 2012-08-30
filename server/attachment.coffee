{Status, VolatileStatus} = require './status'

class @Attachment
  constructor: (name, attributes={}) ->
    @name = name
    {@duration} = attributes

  afterTurn: =>

class @BurnAttachment extends @Attachment
  constructor: (attributes) ->
    super(Status.BURN, attributes)

class @ParalyzeAttachment extends @Attachment
  constructor: (attributes) ->
    super(Status.PARALYZE, attributes)

class @FreezeAttachment extends @Attachment
  constructor: (attributes) ->
    super(Status.FREEZE, attributes)

class @SleepAttachment extends @Attachment
  constructor: (attributes) ->
    super(Status.SLEEP, attributes)

class @PoisonAttachment extends @Attachment
  constructor: (attributes) ->
    super(Status.POISON, attributes)

class @ToxicAttachment extends @Attachment
  constructor: (attributes) ->
    super(Status.TOXIC, attributes)

class @FlinchAttachment extends @Attachment
  constructor: (attributes={}) ->
    attributes.duration ||= 1
    super(VolatileStatus.FLINCH, attributes)

class @ConfusionAttachment extends @Attachment
  constructor: (attributes) ->
    super(VolatileStatus.CONFUSION, attributes)
