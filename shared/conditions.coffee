@Conditions =
  TEAM_PREVIEW             : 1
  RATED_BATTLE             : 2
  PBV_1000                 : 3
  TIMED_BATTLE             : 4
  SLEEP_CLAUSE             : 5
  SPECIES_CLAUSE           : 6
  EVASION_CLAUSE           : 7
  OHKO_CLAUSE              : 8
  UNRELEASED_BAN           : 9
  PRANKSTER_SWAGGER_CLAUSE : 10
  PBV_500                  : 11

@SelectableConditions = [
  @Conditions.TEAM_PREVIEW
  @Conditions.TIMED_BATTLE
  @Conditions.SLEEP_CLAUSE
  @Conditions.EVASION_CLAUSE
  @Conditions.SPECIES_CLAUSE
  @Conditions.PRANKSTER_SWAGGER_CLAUSE
  @Conditions.OHKO_CLAUSE
  @Conditions.UNRELEASED_BAN
]

@HumanizedConditions =
  en:
    TEAM_PREVIEW   : "Team Preview"
    SLEEP_CLAUSE   : "Sleep Clause"
    RATED_BATTLE   : "Rated Battle"
    TIMED_BATTLE   : "Timed Battle"
    SPECIES_CLAUSE : "Species Clause"
    EVASION_CLAUSE : "Evasion Clause"
    OHKO_CLAUSE    : "One-Hit KO Clause"
    UNRELEASED_BAN : "Unreleased Ban"
    PRANKSTER_SWAGGER_CLAUSE : "Prankster + Swagger Clause"

@Formats =
  xy1000:
    generation: 'xy'
    conditions: [ @Conditions.PBV_1000 ]
  xy500:
    generation: 'xy'
    conditions: [ @Conditions.PBV_500 ]

@DEFAULT_FORMAT = 'xy1000'
@LADDER_FORMATS = ['xy1000', 'xy500']
