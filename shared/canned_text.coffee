CannedText =
  bw:
    en:
      MOVE_MISS: "$p avoided the attack!"
      MOVE_FAIL: "But it failed!"
      SUPER_EFFECTIVE: "It's super effective!"
      NOT_VERY_EFFECTIVE: "It's not very effective..."
      CRITICAL_HIT: "A critical hit!"
      GOT_HIT: "$p took $1% damage!"
      DRAIN: "$p had its energy drained!"
      ABSORB: "$p absorbed some HP!"
      NO_TARGET: "But there was no target..."
      RECOIL: "$p was hit by recoil!"
      IMMUNITY: "But it doesn't affect $p..."
      FLINCH: "$p flinched!"
      IS_CONFUSED: "$p is confused!"
      CONFUSION_END: "$p snapped out of confusion!"
      CONFUSION_HURT_SELF: "$p hurt itself in confusion!"
      FATIGUE: "$p became confused due to fatigue!"
      NO_MOVES_LEFT: "$p has no moves left!"
      NO_PP_LEFT: "But there was no PP left for the move!"
      SUN_START:  "The sunlight turned harsh!"
      RAIN_START: "It started to rain!"
      SAND_START: "A sandstorm kicked up!"
      HAIL_START: "It started to hail!"
      SUN_END:  "The sunlight faded."
      RAIN_END: "The rain stopped."
      SAND_END: "The sandstorm subsided."
      HAIL_END: "The hail stopped."
      SAND_CONTINUE: "The sandstorm rages."
      HAIL_CONTINUE: "The hail crashes down."
      SAND_HURT: "$p is buffeted by the sandstorm!"
      HAIL_HURT: "$p is buffeted by the hail!"
      DISABLE_START: "$p's $m was disabled!"
      DISABLE_CONTINUE: "$p's $m is disabled!"
      DISABLE_END: "$p is no longer disabled!"
      YAWN_BEGIN: "$p grew drowsy!"
      TAUNT_PREVENT: "$p can't use $m after the taunt!"
      TAUNT_END: "$p's taunt wore off!"
      WISH_END: "$1's wish came true!"
      PERISH_SONG_START: "All Pokemon hearing the song will faint in three turns!"
      PERISH_SONG_CONTINUE: "$p's perish count fell to $1!"
      TAILWIND_END: "The tailwind petered out!"
      ENCORE_END: "$p's Encore ended!"
      TORMENT_START: "$p was subjected to Torment!"
      SPIKES_HURT: "$p is hurt by the spikes!"
      STEALTH_ROCK_HURT: "$p is hurt by the spikes!"
      TOXIC_SPIKES_END: "The poison spikes disappeared from around $t's team's feet!"
      TRAP_HURT: "$p is hurt by $m!"
      TRAP_END: "$p was freed from $m!"
      LEECH_SEED_START: "$p was seeded!"
      LEECH_SEED_HURT: "$p's health is sapped by Leech Seed!"
      PROTECT_CONTINUE: "$p protected itself!"
      DESTINY_BOND_CONTINUE: "$p took its attacker down with it!"
      SUBSTITUTE_END: "$p's substitute faded!"
      SUBSTITUTE_HURT: "The substitute took damage for $p!"
      BOUNCE_MOVE: "$p bounced the $m back!"
      TRICK_ROOM_END: "The twisted dimensions returned to normal!"
      PARALYZE_START: '$p was paralyzed!'
      FREEZE_START: '$p was frozen!'
      POISON_START: '$p was poisoned!'
      TOXIC_START: '$p was badly poisoned!'
      SLEEP_START: '$p fell asleep!'
      BURN_START: '$p was burned!'
      PARALYZE_CONTINUE: '$p is fully paralyzed!'
      FREEZE_CONTINUE: "$p is frozen solid!"
      POISON_CONTINUE: "$p was hurt by poison!"
      SLEEP_CONTINUE: "$p is fast asleep."
      BURN_CONTINUE: "$p was hurt by its burn!"

cannedMap = {}
cannedMapReverse = {}
allTexts = []
counter = 0

for generationName, generation of CannedText
  for language, cannedTexts of generation
    for cannedTextName in Object.keys(cannedTexts)
      if cannedTextName not of cannedMap
        cannedMap[cannedTextName] = counter
        cannedMapReverse[counter] = cannedTextName
        counter += 1

this.CannedText = cannedMap
this.CannedMap = CannedText
this.CannedMapReverse = cannedMapReverse
