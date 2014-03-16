@PokemonIconBackground = (name, forme) ->
  if not (typeof name == "string")
    pokemon = name
    name = pokemon.name || pokemon.get?("name")
    forme = pokemon.forme || pokemon.get?("forme")
  
  if name  
    id = SpriteIds[name][forme] || SpriteIds[name]["default"]
  else
    id = 0

  x  = (id % 16) * 40
  y  = (id >> 4) * 32
  "background-position: -#{x}px -#{y}px"

@PokemonSprite = (id, forme, options = {}) ->
  if id instanceof Pokemon
    pokemon = id
    id = pokemon.getSpecies()?.id || 0
    forme = pokemon.get('forme')
    options = { shiny: pokemon.get('shiny') } 

  front = options.front ? true
  shiny = options.shiny ? false
  kind  = (if front then "front" else "back")
  kind += "-s"  if shiny
  id    = "000#{id}".substr(-3)
  if forme && forme != 'default' then id += "-#{forme}"
  "http://s3.pokebattle.com/pksprites/#{kind}/#{id}.gif"

@TypeSprite = (type) ->
  "http://s3.pokebattle.com/img/types/#{type.toLowerCase()}.png"

@CategorySprite = (type) ->
  "http://s3.pokebattle.com/img/types/#{type.toLowerCase()}.png"

generation = Generations[DEFAULT_GENERATION.toUpperCase()]
maxSpeciesId = Math.max((p.id  for n, p of generation.SpeciesData)...)
NON_DEFAULT_FORMES_OFFSET = maxSpeciesId + (16 - ((maxSpeciesId + 1) % 16))

# TODO: Move this elswhere
SpriteIds = {
  "Abomasnow": {
    "default": 460,
    "mega": NON_DEFAULT_FORMES_OFFSET + 142
  },
  "Abra": {
    "default": 63
  },
  "Absol": {
    "default": 359,
    "mega": NON_DEFAULT_FORMES_OFFSET + 137
  },
  "Accelgor": {
    "default": 617
  },
  "Aerodactyl": {
    "default": 142,
    "mega": NON_DEFAULT_FORMES_OFFSET + 122
  },
  "Aggron": {
    "default": 306,
    "mega": NON_DEFAULT_FORMES_OFFSET + 133
  },
  "Aipom": {
    "default": 190
  },
  "Alakazam": {
    "default": 65,
    "mega": NON_DEFAULT_FORMES_OFFSET + 117
  },
  "Alomomola": {
    "default": 594
  },
  "Altaria": {
    "default": 334
  },
  "Ambipom": {
    "default": 424
  },
  "Amoonguss": {
    "default": 591
  },
  "Ampharos": {
    "default": 181,
    "mega": NON_DEFAULT_FORMES_OFFSET + 125
  },
  "Anorith": {
    "default": 347
  },
  "Arbok": {
    "default": 24
  },
  "Arcanine": {
    "default": 59
  },
  "Arceus": {
    "default": 493
  },
  "Archen": {
    "default": 566
  },
  "Archeops": {
    "default": 567
  },
  "Ariados": {
    "default": 168
  },
  "Armaldo": {
    "default": 348
  },
  "Aron": {
    "default": 304
  },
  "Articuno": {
    "default": 144
  },
  "Audino": {
    "default": 531
  },
  "Axew": {
    "default": 610
  },
  "Azelf": {
    "default": 482
  },
  "Azumarill": {
    "default": 184
  },
  "Azurill": {
    "default": 298
  },
  "Bagon": {
    "default": 371
  },
  "Baltoy": {
    "default": 343
  },
  "Banette": {
    "default": 354,
    "mega": NON_DEFAULT_FORMES_OFFSET + 136
  },
  "Barboach": {
    "default": 339
  },
  "Basculin": {
    "default": 550,
    "blue-striped": NON_DEFAULT_FORMES_OFFSET + 78
  },
  "Bastiodon": {
    "default": 411
  },
  "Bayleef": {
    "default": 153
  },
  "Beartic": {
    "default": 614
  },
  "Beautifly": {
    "default": 267
  },
  "Beedrill": {
    "default": 15
  },
  "Beheeyem": {
    "default": 606
  },
  "Beldum": {
    "default": 374
  },
  "Bellossom": {
    "default": 182
  },
  "Bellsprout": {
    "default": 69
  },
  "Bibarel": {
    "default": 400
  },
  "Bidoof": {
    "default": 399
  },
  "Bisharp": {
    "default": 625
  },
  "Blastoise": {
    "default": 9,
    "mega": NON_DEFAULT_FORMES_OFFSET + 116
  },
  "Blaziken": {
    "default": 257,
    "mega": NON_DEFAULT_FORMES_OFFSET + 130
  },
  "Blissey": {
    "default": 242
  },
  "Blitzle": {
    "default": 522
  },
  "Boldore": {
    "default": 525
  },
  "Bonsly": {
    "default": 438
  },
  "Bouffalant": {
    "default": 626
  },
  "Braviary": {
    "default": 628
  },
  "Breloom": {
    "default": 286
  },
  "Bronzong": {
    "default": 437
  },
  "Bronzor": {
    "default": 436
  },
  "Budew": {
    "default": 406
  },
  "Buizel": {
    "default": 418
  },
  "Bulbasaur": {
    "default": 1
  },
  "Buneary": {
    "default": 427
  },
  "Burmy": {
    "default": 412,
    "sandy": NON_DEFAULT_FORMES_OFFSET + 9,
    "trash": NON_DEFAULT_FORMES_OFFSET + 10
  },
  "Butterfree": {
    "default": 12
  },
  "Cacnea": {
    "default": 331
  },
  "Cacturne": {
    "default": 332
  },
  "Camerupt": {
    "default": 323
  },
  "Carnivine": {
    "default": 455
  },
  "Carracosta": {
    "default": 565
  },
  "Carvanha": {
    "default": 318
  },
  "Cascoon": {
    "default": 268
  },
  "Castform": {
    "default": 351,
    "rainy": 49,
    "snowy": 50,
    "sunny": 51
  },
  "Caterpie": {
    "default": 10
  },
  "Celebi": {
    "default": 251
  },
  "Chandelure": {
    "default": 609
  },
  "Chansey": {
    "default": 113
  },
  "Charizard": {
    "default": 6,
    "mega-x": NON_DEFAULT_FORMES_OFFSET + 114,
    "mega-y": NON_DEFAULT_FORMES_OFFSET + 115
  },
  "Charmander": {
    "default": 4
  },
  "Charmeleon": {
    "default": 5
  },
  "Chatot": {
    "default": 441
  },
  "Cherrim": {
    "default": 421
  },
  "Cherubi": {
    "default": 420
  },
  "Chikorita": {
    "default": 152
  },
  "Chimchar": {
    "default": 390
  },
  "Chimecho": {
    "default": 358
  },
  "Chinchou": {
    "default": 170
  },
  "Chingling": {
    "default": 433
  },
  "Cinccino": {
    "default": 573
  },
  "Clamperl": {
    "default": 366
  },
  "Claydol": {
    "default": 344
  },
  "Clefable": {
    "default": 36
  },
  "Clefairy": {
    "default": 35
  },
  "Cleffa": {
    "default": 173
  },
  "Cloyster": {
    "default": 91
  },
  "Cobalion": {
    "default": 638
  },
  "Cofagrigus": {
    "default": 563
  },
  "Combee": {
    "default": 415
  },
  "Combusken": {
    "default": 256
  },
  "Conkeldurr": {
    "default": 534
  },
  "Corphish": {
    "default": 341
  },
  "Corsola": {
    "default": 222
  },
  "Cottonee": {
    "default": 546
  },
  "Cradily": {
    "default": 346
  },
  "Cranidos": {
    "default": 408
  },
  "Crawdaunt": {
    "default": 342
  },
  "Cresselia": {
    "default": 488
  },
  "Croagunk": {
    "default": 453
  },
  "Crobat": {
    "default": 169
  },
  "Croconaw": {
    "default": 159
  },
  "Crustle": {
    "default": 558
  },
  "Cryogonal": {
    "default": 615
  },
  "Cubchoo": {
    "default": 613
  },
  "Cubone": {
    "default": 104
  },
  "Cyndaquil": {
    "default": 155
  },
  "Darkrai": {
    "default": 491
  },
  "Darmanitan": {
    "default": 555,
    "zen": NON_DEFAULT_FORMES_OFFSET + 81
  },
  "Darumaka": {
    "default": 554
  },
  "Deerling": {
    "default": 585
  },
  "Deino": {
    "default": 633
  },
  "Delcatty": {
    "default": 301
  },
  "Delibird": {
    "default": 225
  },
  "Deoxys": {
    "default": 386,
    "attack": NON_DEFAULT_FORMES_OFFSET + 52,
    "defense": NON_DEFAULT_FORMES_OFFSET + 53,
    "speed": NON_DEFAULT_FORMES_OFFSET + 55
  },
  "Dewgong": {
    "default": 87
  },
  "Dewott": {
    "default": 502
  },
  "Dialga": {
    "default": 483
  },
  "Diglett": {
    "default": 50
  },
  "Ditto": {
    "default": 132
  },
  "Dodrio": {
    "default": 85
  },
  "Doduo": {
    "default": 84
  },
  "Donphan": {
    "default": 232
  },
  "Dragonair": {
    "default": 148
  },
  "Dragonite": {
    "default": 149
  },
  "Drapion": {
    "default": 452
  },
  "Dratini": {
    "default": 147
  },
  "Drifblim": {
    "default": 426
  },
  "Drifloon": {
    "default": 425
  },
  "Drilbur": {
    "default": 529
  },
  "Drowzee": {
    "default": 96
  },
  "Druddigon": {
    "default": 621
  },
  "Ducklett": {
    "default": 580
  },
  "Dugtrio": {
    "default": 51
  },
  "Dunsparce": {
    "default": 206
  },
  "Duosion": {
    "default": 578
  },
  "Durant": {
    "default": 632
  },
  "Dusclops": {
    "default": 356
  },
  "Dusknoir": {
    "default": 477
  },
  "Duskull": {
    "default": 355
  },
  "Dustox": {
    "default": 269
  },
  "Dwebble": {
    "default": 557
  },
  "Eelektrik": {
    "default": 603
  },
  "Eelektross": {
    "default": 604
  },
  "Eevee": {
    "default": 133
  },
  "Ekans": {
    "default": 23
  },
  "Electabuzz": {
    "default": 125
  },
  "Electivire": {
    "default": 466
  },
  "Electrike": {
    "default": 309
  },
  "Electrode": {
    "default": 101
  },
  "Elekid": {
    "default": 239
  },
  "Elgyem": {
    "default": 605
  },
  "Emboar": {
    "default": 500
  },
  "Emolga": {
    "default": 587
  },
  "Empoleon": {
    "default": 395
  },
  "Entei": {
    "default": 244
  },
  "Escavalier": {
    "default": 589
  },
  "Espeon": {
    "default": 196
  },
  "Excadrill": {
    "default": 530
  },
  "Exeggcute": {
    "default": 102
  },
  "Exeggutor": {
    "default": 103
  },
  "Exploud": {
    "default": 295
  },
  "Farfetch'd": {
    "default": 83
  },
  "Fearow": {
    "default": 22
  },
  "Feebas": {
    "default": 349
  },
  "Feraligatr": {
    "default": 160
  },
  "Ferroseed": {
    "default": 597
  },
  "Ferrothorn": {
    "default": 598
  },
  "Finneon": {
    "default": 456
  },
  "Flaaffy": {
    "default": 180
  },
  "Flareon": {
    "default": 136
  },
  "Floatzel": {
    "default": 419
  },
  "Flygon": {
    "default": 330
  },
  "Foongus": {
    "default": 590
  },
  "Forretress": {
    "default": 205
  },
  "Fraxure": {
    "default": 611
  },
  "Frillish": {
    "default": 592
  },
  "Froslass": {
    "default": 478
  },
  "Furret": {
    "default": 162
  },
  "Gabite": {
    "default": 444
  },
  "Gallade": {
    "default": 475
  },
  "Galvantula": {
    "default": 596
  },
  "Garbodor": {
    "default": 569
  },
  "Garchomp": {
    "default": 445,
    "mega": NON_DEFAULT_FORMES_OFFSET + 140
  },
  "Gardevoir": {
    "default": 282,
    "mega": NON_DEFAULT_FORMES_OFFSET + 131
  },
  "Gastly": {
    "default": 92
  },
  "Gastrodon": {
    "default": 423
  },
  "Genesect": {
    "default": 649
  },
  "Gengar": {
    "default": 94,
    "mega": NON_DEFAULT_FORMES_OFFSET + 118
  },
  "Geodude": {
    "default": 74
  },
  "Gible": {
    "default": 443
  },
  "Gigalith": {
    "default": 526
  },
  "Girafarig": {
    "default": 203
  },
  "Giratina": {
    "default": 487,
    "origin": NON_DEFAULT_FORMES_OFFSET + 74
  },
  "Glaceon": {
    "default": 471
  },
  "Glalie": {
    "default": 362
  },
  "Glameow": {
    "default": 431
  },
  "Gligar": {
    "default": 207
  },
  "Gliscor": {
    "default": 472
  },
  "Gloom": {
    "default": 44
  },
  "Golbat": {
    "default": 42
  },
  "Goldeen": {
    "default": 118
  },
  "Golduck": {
    "default": 55
  },
  "Golem": {
    "default": 76
  },
  "Golett": {
    "default": 622
  },
  "Golurk": {
    "default": 623
  },
  "Gorebyss": {
    "default": 368
  },
  "Gothita": {
    "default": 574
  },
  "Gothitelle": {
    "default": 576
  },
  "Gothorita": {
    "default": 575
  },
  "Granbull": {
    "default": 210
  },
  "Graveler": {
    "default": 75
  },
  "Grimer": {
    "default": 88
  },
  "Grotle": {
    "default": 388
  },
  "Groudon": {
    "default": 383
  },
  "Grovyle": {
    "default": 253
  },
  "Growlithe": {
    "default": 58
  },
  "Grumpig": {
    "default": 326
  },
  "Gulpin": {
    "default": 316
  },
  "Gurdurr": {
    "default": 533
  },
  "Gyarados": {
    "default": 130,
    "mega": NON_DEFAULT_FORMES_OFFSET + 121
  },
  "Happiny": {
    "default": 440
  },
  "Hariyama": {
    "default": 297
  },
  "Haunter": {
    "default": 93
  },
  "Haxorus": {
    "default": 612
  },
  "Heatmor": {
    "default": 631
  },
  "Heatran": {
    "default": 485
  },
  "Heracross": {
    "default": 214,
    "mega": NON_DEFAULT_FORMES_OFFSET + 127
  },
  "Herdier": {
    "default": 507
  },
  "Hippopotas": {
    "default": 449
  },
  "Hippowdon": {
    "default": 450
  },
  "Hitmonchan": {
    "default": 107
  },
  "Hitmonlee": {
    "default": 106
  },
  "Hitmontop": {
    "default": 237
  },
  "Ho-Oh": {
    "default": 250
  },
  "Honchkrow": {
    "default": 430
  },
  "Hoothoot": {
    "default": 163
  },
  "Hoppip": {
    "default": 187
  },
  "Horsea": {
    "default": 116
  },
  "Houndoom": {
    "default": 229,
    "mega": NON_DEFAULT_FORMES_OFFSET + 128
  },
  "Houndour": {
    "default": 228
  },
  "Huntail": {
    "default": 367
  },
  "Hydreigon": {
    "default": 635
  },
  "Hypno": {
    "default": 97
  },
  "Igglybuff": {
    "default": 174
  },
  "Illumise": {
    "default": 314
  },
  "Infernape": {
    "default": 392
  },
  "Ivysaur": {
    "default": 2
  },
  "Jellicent": {
    "default": 593
  },
  "Jigglypuff": {
    "default": 39
  },
  "Jirachi": {
    "default": 385
  },
  "Jolteon": {
    "default": 135
  },
  "Joltik": {
    "default": 595
  },
  "Jumpluff": {
    "default": 189
  },
  "Jynx": {
    "default": 124
  },
  "Kabuto": {
    "default": 140
  },
  "Kabutops": {
    "default": 141
  },
  "Kadabra": {
    "default": 64
  },
  "Kakuna": {
    "default": 14
  },
  "Kangaskhan": {
    "default": 115,
    "mega": NON_DEFAULT_FORMES_OFFSET + 119
  },
  "Karrablast": {
    "default": 588
  },
  "Kecleon": {
    "default": 352
  },
  "Keldeo": {
    "default": 647,
    "resolute": NON_DEFAULT_FORMES_OFFSET + 103
  },
  "Kingdra": {
    "default": 230
  },
  "Kingler": {
    "default": 99
  },
  "Kirlia": {
    "default": 281
  },
  "Klang": {
    "default": 600
  },
  "Klink": {
    "default": 599
  },
  "Klinklang": {
    "default": 601
  },
  "Koffing": {
    "default": 109
  },
  "Krabby": {
    "default": 98
  },
  "Kricketot": {
    "default": 401
  },
  "Kricketune": {
    "default": 402
  },
  "Krokorok": {
    "default": 552
  },
  "Krookodile": {
    "default": 553
  },
  "Kyogre": {
    "default": 382
  },
  "Kyurem": {
    "default": 646,
    "black": NON_DEFAULT_FORMES_OFFSET + 101,
    "white": NON_DEFAULT_FORMES_OFFSET + 102
  },
  "Lairon": {
    "default": 305
  },
  "Lampent": {
    "default": 608
  },
  "Landorus": {
    "default": 645,
    "therian": NON_DEFAULT_FORMES_OFFSET + 100
  },
  "Lanturn": {
    "default": 171
  },
  "Lapras": {
    "default": 131
  },
  "Larvesta": {
    "default": 636
  },
  "Larvitar": {
    "default": 246
  },
  "Latias": {
    "default": 380,
    "mega": NON_DEFAULT_FORMES_OFFSET + 138
  },
  "Latios": {
    "default": 381,
    "mega": NON_DEFAULT_FORMES_OFFSET + 139
  },
  "Leafeon": {
    "default": 470
  },
  "Leavanny": {
    "default": 542
  },
  "Ledian": {
    "default": 166
  },
  "Ledyba": {
    "default": 165
  },
  "Lickilicky": {
    "default": 463
  },
  "Lickitung": {
    "default": 108
  },
  "Liepard": {
    "default": 510
  },
  "Lileep": {
    "default": 345
  },
  "Lilligant": {
    "default": 549
  },
  "Lillipup": {
    "default": 506
  },
  "Linoone": {
    "default": 264
  },
  "Litwick": {
    "default": 607
  },
  "Lombre": {
    "default": 271
  },
  "Lopunny": {
    "default": 428
  },
  "Lotad": {
    "default": 270
  },
  "Loudred": {
    "default": 294
  },
  "Lucario": {
    "default": 448,
    "mega": NON_DEFAULT_FORMES_OFFSET + 141
  },
  "Ludicolo": {
    "default": 272
  },
  "Lugia": {
    "default": 249
  },
  "Lumineon": {
    "default": 457
  },
  "Lunatone": {
    "default": 337
  },
  "Luvdisc": {
    "default": 370
  },
  "Luxio": {
    "default": 404
  },
  "Luxray": {
    "default": 405
  },
  "Machamp": {
    "default": 68
  },
  "Machoke": {
    "default": 67
  },
  "Machop": {
    "default": 66
  },
  "Magby": {
    "default": 240
  },
  "Magcargo": {
    "default": 219
  },
  "Magikarp": {
    "default": 129
  },
  "Magmar": {
    "default": 126
  },
  "Magmortar": {
    "default": 467
  },
  "Magnemite": {
    "default": 81
  },
  "Magneton": {
    "default": 82
  },
  "Magnezone": {
    "default": 462
  },
  "Makuhita": {
    "default": 296
  },
  "Mamoswine": {
    "default": 473
  },
  "Manaphy": {
    "default": 490
  },
  "Mandibuzz": {
    "default": 630
  },
  "Manectric": {
    "default": 310,
    "mega": NON_DEFAULT_FORMES_OFFSET + 135
  },
  "Mankey": {
    "default": 56
  },
  "Mantine": {
    "default": 226
  },
  "Mantyke": {
    "default": 458
  },
  "Maractus": {
    "default": 556
  },
  "Mareep": {
    "default": 179
  },
  "Marill": {
    "default": 183
  },
  "Marowak": {
    "default": 105
  },
  "Marshtomp": {
    "default": 259
  },
  "Masquerain": {
    "default": 284
  },
  "Mawile": {
    "default": 303,
    "mega": NON_DEFAULT_FORMES_OFFSET + 132
  },
  "Medicham": {
    "default": 308,
    "mega": NON_DEFAULT_FORMES_OFFSET + 134
  },
  "Meditite": {
    "default": 307
  },
  "Meganium": {
    "default": 154
  },
  "Meloetta": {
    "default": 648,
    "pirouette": NON_DEFAULT_FORMES_OFFSET + 93
  },
  "Meowth": {
    "default": 52
  },
  "Mesprit": {
    "default": 481
  },
  "Metagross": {
    "default": 376
  },
  "Metang": {
    "default": 375
  },
  "Metapod": {
    "default": 11
  },
  "Mew": {
    "default": 151
  },
  "Mewtwo": {
    "default": 150,
    "mega-x": NON_DEFAULT_FORMES_OFFSET + 123
    "mega-y": NON_DEFAULT_FORMES_OFFSET + 124
  },
  "Mienfoo": {
    "default": 619
  },
  "Mienshao": {
    "default": 620
  },
  "Mightyena": {
    "default": 262
  },
  "Milotic": {
    "default": 350
  },
  "Miltank": {
    "default": 241
  },
  "Mime Jr.": {
    "default": 439
  },
  "Minccino": {
    "default": 572
  },
  "Minun": {
    "default": 312
  },
  "Misdreavus": {
    "default": 200
  },
  "Mismagius": {
    "default": 429
  },
  "Moltres": {
    "default": 146
  },
  "Monferno": {
    "default": 391
  },
  "Mothim": {
    "default": 414
  },
  "Mr. Mime": {
    "default": 122
  },
  "Mudkip": {
    "default": 258
  },
  "Muk": {
    "default": 89
  },
  "Munchlax": {
    "default": 446
  },
  "Munna": {
    "default": 517
  },
  "Murkrow": {
    "default": 198
  },
  "Musharna": {
    "default": 518
  },
  "Natu": {
    "default": 177
  },
  "Nidoking": {
    "default": 34
  },
  "Nidoqueen": {
    "default": 31
  },
  "Nidoran♀": {
    "default": 29
  },
  "Nidoran♂": {
    "default": 32
  },
  "Nidorina": {
    "default": 30
  },
  "Nidorino": {
    "default": 33
  },
  "Nincada": {
    "default": 290
  },
  "Ninetales": {
    "default": 38
  },
  "Ninjask": {
    "default": 291
  },
  "Noctowl": {
    "default": 164
  },
  "Nosepass": {
    "default": 299
  },
  "Numel": {
    "default": 322
  },
  "Nuzleaf": {
    "default": 274
  },
  "Octillery": {
    "default": 224
  },
  "Oddish": {
    "default": 43
  },
  "Omanyte": {
    "default": 138
  },
  "Omastar": {
    "default": 139
  },
  "Onix": {
    "default": 95
  },
  "Oshawott": {
    "default": 501
  },
  "Pachirisu": {
    "default": 417
  },
  "Palkia": {
    "default": 484
  },
  "Palpitoad": {
    "default": 536
  },
  "Panpour": {
    "default": 515
  },
  "Pansage": {
    "default": 511
  },
  "Pansear": {
    "default": 513
  },
  "Paras": {
    "default": 46
  },
  "Parasect": {
    "default": 47
  },
  "Patrat": {
    "default": 504
  },
  "Pawniard": {
    "default": 624
  },
  "Pelipper": {
    "default": 279
  },
  "Persian": {
    "default": 53
  },
  "Petilil": {
    "default": 548
  },
  "Phanpy": {
    "default": 231
  },
  "Phione": {
    "default": 489
  },
  "Pichu": {
    "default": 172
  },
  "Pidgeot": {
    "default": 18
  },
  "Pidgeotto": {
    "default": 17
  },
  "Pidgey": {
    "default": 16
  },
  "Pidove": {
    "default": 519
  },
  "Pignite": {
    "default": 499
  },
  "Pikachu": {
    "default": 25
  },
  "Piloswine": {
    "default": 221
  },
  "Pineco": {
    "default": 204
  },
  "Pinsir": {
    "default": 127,
    "mega": NON_DEFAULT_FORMES_OFFSET + 120
  },
  "Piplup": {
    "default": 393
  },
  "Plusle": {
    "default": 311
  },
  "Politoed": {
    "default": 186
  },
  "Poliwag": {
    "default": 60
  },
  "Poliwhirl": {
    "default": 61
  },
  "Poliwrath": {
    "default": 62
  },
  "Ponyta": {
    "default": 77
  },
  "Poochyena": {
    "default": 261
  },
  "Porygon": {
    "default": 137
  },
  "Porygon-Z": {
    "default": 474
  },
  "Porygon2": {
    "default": 233
  },
  "Primeape": {
    "default": 57
  },
  "Prinplup": {
    "default": 394
  },
  "Probopass": {
    "default": 476
  },
  "Psyduck": {
    "default": 54
  },
  "Pupitar": {
    "default": 247
  },
  "Purrloin": {
    "default": 509
  },
  "Purugly": {
    "default": 432
  },
  "Quagsire": {
    "default": 195
  },
  "Quilava": {
    "default": 156
  },
  "Qwilfish": {
    "default": 211
  },
  "Raichu": {
    "default": 26
  },
  "Raikou": {
    "default": 243
  },
  "Ralts": {
    "default": 280
  },
  "Rampardos": {
    "default": 409
  },
  "Rapidash": {
    "default": 78
  },
  "Raticate": {
    "default": 20
  },
  "Rattata": {
    "default": 19
  },
  "Rayquaza": {
    "default": 384
  },
  "Regice": {
    "default": 378
  },
  "Regigigas": {
    "default": 486
  },
  "Regirock": {
    "default": 377
  },
  "Registeel": {
    "default": 379
  },
  "Relicanth": {
    "default": 369
  },
  "Remoraid": {
    "default": 223
  },
  "Reshiram": {
    "default": 643
  },
  "Reuniclus": {
    "default": 579
  },
  "Rhydon": {
    "default": 112
  },
  "Rhyhorn": {
    "default": 111
  },
  "Rhyperior": {
    "default": 464
  },
  "Riolu": {
    "default": 447
  },
  "Roggenrola": {
    "default": 524
  },
  "Roselia": {
    "default": 315
  },
  "Roserade": {
    "default": 407
  },
  "Rotom": {
    "default": 479,
    "fan": NON_DEFAULT_FORMES_OFFSET + 68,
    "frost": NON_DEFAULT_FORMES_OFFSET + 69,
    "heat": NON_DEFAULT_FORMES_OFFSET + 70,
    "mow": NON_DEFAULT_FORMES_OFFSET + 71,
    "wash": NON_DEFAULT_FORMES_OFFSET + 72
  },
  "Rufflet": {
    "default": 627
  },
  "Sableye": {
    "default": 302
  },
  "Salamence": {
    "default": 373
  },
  "Samurott": {
    "default": 503
  },
  "Sandile": {
    "default": 551
  },
  "Sandshrew": {
    "default": 27
  },
  "Sandslash": {
    "default": 28
  },
  "Sawk": {
    "default": 539
  },
  "Sawsbuck": {
    "default": 586
  },
  "Sceptile": {
    "default": 254
  },
  "Scizor": {
    "default": 212,
    "mega": NON_DEFAULT_FORMES_OFFSET + 126
  },
  "Scolipede": {
    "default": 545
  },
  "Scrafty": {
    "default": 560
  },
  "Scraggy": {
    "default": 559
  },
  "Scyther": {
    "default": 123
  },
  "Seadra": {
    "default": 117
  },
  "Seaking": {
    "default": 119
  },
  "Sealeo": {
    "default": 364
  },
  "Seedot": {
    "default": 273
  },
  "Seel": {
    "default": 86
  },
  "Seismitoad": {
    "default": 537
  },
  "Sentret": {
    "default": 161
  },
  "Serperior": {
    "default": 497
  },
  "Servine": {
    "default": 496
  },
  "Seviper": {
    "default": 336
  },
  "Sewaddle": {
    "default": 540
  },
  "Sharpedo": {
    "default": 319
  },
  "Shaymin": {
    "default": 492,
    "sky": NON_DEFAULT_FORMES_OFFSET + 76
  },
  "Shedinja": {
    "default": 292
  },
  "Shelgon": {
    "default": 372
  },
  "Shellder": {
    "default": 90
  },
  "Shellos": {
    "default": 422
  },
  "Shelmet": {
    "default": 616
  },
  "Shieldon": {
    "default": 410
  },
  "Shiftry": {
    "default": 275
  },
  "Shinx": {
    "default": 403
  },
  "Shroomish": {
    "default": 285
  },
  "Shuckle": {
    "default": 213
  },
  "Shuppet": {
    "default": 353
  },
  "Sigilyph": {
    "default": 561
  },
  "Silcoon": {
    "default": 266
  },
  "Simipour": {
    "default": 516
  },
  "Simisage": {
    "default": 512
  },
  "Simisear": {
    "default": 514
  },
  "Skarmory": {
    "default": 227
  },
  "Skiploom": {
    "default": 188
  },
  "Skitty": {
    "default": 300
  },
  "Skorupi": {
    "default": 451
  },
  "Skuntank": {
    "default": 435
  },
  "Slaking": {
    "default": 289
  },
  "Slakoth": {
    "default": 287
  },
  "Slowbro": {
    "default": 80
  },
  "Slowking": {
    "default": 199
  },
  "Slowpoke": {
    "default": 79
  },
  "Slugma": {
    "default": 218
  },
  "Smeargle": {
    "default": 235
  },
  "Smoochum": {
    "default": 238
  },
  "Sneasel": {
    "default": 215
  },
  "Snivy": {
    "default": 495
  },
  "Snorlax": {
    "default": 143
  },
  "Snorunt": {
    "default": 361
  },
  "Snover": {
    "default": 459
  },
  "Snubbull": {
    "default": 209
  },
  "Solosis": {
    "default": 577
  },
  "Solrock": {
    "default": 338
  },
  "Spearow": {
    "default": 21
  },
  "Spheal": {
    "default": 363
  },
  "Spinarak": {
    "default": 167
  },
  "Spinda": {
    "default": 327
  },
  "Spiritomb": {
    "default": 442
  },
  "Spoink": {
    "default": 325
  },
  "Squirtle": {
    "default": 7
  },
  "Stantler": {
    "default": 234
  },
  "Staraptor": {
    "default": 398
  },
  "Staravia": {
    "default": 397
  },
  "Starly": {
    "default": 396
  },
  "Starmie": {
    "default": 121
  },
  "Staryu": {
    "default": 120
  },
  "Steelix": {
    "default": 208
  },
  "Stoutland": {
    "default": 508
  },
  "Stunfisk": {
    "default": 618
  },
  "Stunky": {
    "default": 434
  },
  "Sudowoodo": {
    "default": 185
  },
  "Suicune": {
    "default": 245
  },
  "Sunflora": {
    "default": 192
  },
  "Sunkern": {
    "default": 191
  },
  "Surskit": {
    "default": 283
  },
  "Swablu": {
    "default": 333
  },
  "Swadloon": {
    "default": 541
  },
  "Swalot": {
    "default": 317
  },
  "Swampert": {
    "default": 260
  },
  "Swanna": {
    "default": 581
  },
  "Swellow": {
    "default": 277
  },
  "Swinub": {
    "default": 220
  },
  "Swoobat": {
    "default": 528
  },
  "Taillow": {
    "default": 276
  },
  "Tangela": {
    "default": 114
  },
  "Tangrowth": {
    "default": 465
  },
  "Tauros": {
    "default": 128
  },
  "Teddiursa": {
    "default": 216
  },
  "Tentacool": {
    "default": 72
  },
  "Tentacruel": {
    "default": 73
  },
  "Tepig": {
    "default": 498
  },
  "Terrakion": {
    "default": 639
  },
  "Throh": {
    "default": 538
  },
  "Thundurus": {
    "default": 642,
    "therian": NON_DEFAULT_FORMES_OFFSET + 99
  },
  "Timburr": {
    "default": 532
  },
  "Tirtouga": {
    "default": 564
  },
  "Togekiss": {
    "default": 468
  },
  "Togepi": {
    "default": 175
  },
  "Togetic": {
    "default": 176
  },
  "Torchic": {
    "default": 255
  },
  "Torkoal": {
    "default": 324
  },
  "Tornadus": {
    "default": 641,
    "therian": NON_DEFAULT_FORMES_OFFSET + 98
  },
  "Torterra": {
    "default": 389
  },
  "Totodile": {
    "default": 158
  },
  "Toxicroak": {
    "default": 454
  },
  "Tranquill": {
    "default": 520
  },
  "Trapinch": {
    "default": 328
  },
  "Treecko": {
    "default": 252
  },
  "Tropius": {
    "default": 357
  },
  "Trubbish": {
    "default": 568
  },
  "Turtwig": {
    "default": 387
  },
  "Tympole": {
    "default": 535
  },
  "Tynamo": {
    "default": 602
  },
  "Typhlosion": {
    "default": 157
  },
  "Tyranitar": {
    "default": 248,
    "mega": NON_DEFAULT_FORMES_OFFSET + 129
  },
  "Tyrogue": {
    "default": 236
  },
  "Umbreon": {
    "default": 197
  },
  "Unfezant": {
    "default": 521
  },
  "Unown": {
    "default": 201
  },
  "Ursaring": {
    "default": 217
  },
  "Uxie": {
    "default": 480
  },
  "Vanillish": {
    "default": 583
  },
  "Vanillite": {
    "default": 582
  },
  "Vanilluxe": {
    "default": 584
  },
  "Vaporeon": {
    "default": 134
  },
  "Venipede": {
    "default": 543
  },
  "Venomoth": {
    "default": 49
  },
  "Venonat": {
    "default": 48
  },
  "Venusaur": {
    "default": 3,
    "mega": NON_DEFAULT_FORMES_OFFSET + 113
  },
  "Vespiquen": {
    "default": 416
  },
  "Vibrava": {
    "default": 329
  },
  "Victini": {
    "default": 494
  },
  "Victreebel": {
    "default": 71
  },
  "Vigoroth": {
    "default": 288
  },
  "Vileplume": {
    "default": 45
  },
  "Virizion": {
    "default": 640
  },
  "Volbeat": {
    "default": 313
  },
  "Volcarona": {
    "default": 637
  },
  "Voltorb": {
    "default": 100
  },
  "Vullaby": {
    "default": 629
  },
  "Vulpix": {
    "default": 37
  },
  "Wailmer": {
    "default": 320
  },
  "Wailord": {
    "default": 321
  },
  "Walrein": {
    "default": 365
  },
  "Wartortle": {
    "default": 8
  },
  "Watchog": {
    "default": 505
  },
  "Weavile": {
    "default": 461
  },
  "Weedle": {
    "default": 13
  },
  "Weepinbell": {
    "default": 70
  },
  "Weezing": {
    "default": 110
  },
  "Whimsicott": {
    "default": 547
  },
  "Whirlipede": {
    "default": 544
  },
  "Whiscash": {
    "default": 340
  },
  "Whismur": {
    "default": 293
  },
  "Wigglytuff": {
    "default": 40
  },
  "Wingull": {
    "default": 278
  },
  "Wobbuffet": {
    "default": 202
  },
  "Woobat": {
    "default": 527
  },
  "Wooper": {
    "default": 194
  },
  "Wormadam": {
    "default": 413,
    "sandy": NON_DEFAULT_FORMES_OFFSET + 60,
    "trash": NON_DEFAULT_FORMES_OFFSET + 61
  },
  "Wurmple": {
    "default": 265
  },
  "Wynaut": {
    "default": 360
  },
  "Xatu": {
    "default": 178
  },
  "Yamask": {
    "default": 562
  },
  "Yanma": {
    "default": 193
  },
  "Yanmega": {
    "default": 469
  },
  "Zangoose": {
    "default": 335
  },
  "Zapdos": {
    "default": 145
  },
  "Zebstrika": {
    "default": 523
  },
  "Zekrom": {
    "default": 644
  },
  "Zigzagoon": {
    "default": 263
  },
  "Zoroark": {
    "default": 571
  },
  "Zorua": {
    "default": 570
  },
  "Zubat": {
    "default": 41
  },
  "Zweilous": {
    "default": 634
  },
  "Aegislash": {
    "default": 681,
    "blade": NON_DEFAULT_FORMES_OFFSET + 106
  },
  "Amaura": {
    "default": 698
  },
  "Aromatisse": {
    "default": 683
  },
  "Aurorus": {
    "default": 699
  },
  "Avalugg": {
    "default": 713
  },
  "Barbaracle": {
    "default": 689
  },
  "Bergmite": {
    "default": 712
  },
  "Binacle": {
    "default": 688
  },
  "Braixen": {
    "default": 654
  },
  "Bunnelby": {
    "default": 659
  },
  "Carbink": {
    "default": 703
  },
  "Chesnaught": {
    "default": 652
  },
  "Chespin": {
    "default": 650
  },
  "Clawitzer": {
    "default": 693
  },
  "Clauncher": {
    "default": 692
  },
  "Dedenne": {
    "default": 702
  },
  "Delphox": {
    "default": 655
  },
  "Diggersby": {
    "default": 660
  },
  "Doublade": {
    "default": 680
  },
  "Dragalge": {
    "default": 691
  },
  "Espurr": {
    "default": 677
  },
  "Fennekin": {
    "default": 653
  },
  "Flabébé": {
    "default": 669
  },
  "Fletchinder": {
    "default": 662
  },
  "Fletchling": {
    "default": 661
  },
  "Floette": {
    "default": 670
  },
  "Florges": {
    "default": 671
  },
  "Froakie": {
    "default": 656
  },
  "Frogadier": {
    "default": 657
  },
  "Furfrou": {
    "default": 676
  },
  "Gogoat": {
    "default": 673
  },
  "Goodra": {
    "default": 706
  },
  "Goomy": {
    "default": 704
  },
  "Gourgeist": {
    "default": 711
  },
  "Greninja": {
    "default": 658
  },
  "Hawlucha": {
    "default": 701
  },
  "Heliolisk": {
    "default": 695
  },
  "Helioptile": {
    "default": 694
  },
  "Honedge": {
    "default": 679
  },
  "Inkay": {
    "default": 686
  },
  "Klefki": {
    "default": 707
  },
  "Litleo": {
    "default": 667
  },
  "Malamar": {
    "default": 687
  },
  "Meowstic": {
    "default": 678,
    "female": NON_DEFAULT_FORMES_OFFSET + 105
  },
  "Noibat": {
    "default": 714
  },
  "Noivern": {
    "default": 715
  },
  "Pancham": {
    "default": 674
  },
  "Pangoro": {
    "default": 675
  },
  "Phantump": {
    "default": 708
  },
  "Pumpkaboo": {
    "default": 710
  },
  "Pyroar": {
    "default": 668
  },
  "Quilladin": {
    "default": 651
  },
  "Scatterbug": {
    "default": 664
  },
  "Skiddo": {
    "default": 672
  },
  "Skrelp": {
    "default": 690
  },
  "Sliggoo": {
    "default": 705
  },
  "Slurpuff": {
    "default": 685
  },
  "Spewpa": {
    "default": 665
  },
  "Spritzee": {
    "default": 682
  },
  "Swirlix": {
    "default": 684
  },
  "Sylveon": {
    "default": 700
  },
  "Talonflame": {
    "default": 663
  },
  "Trevenant": {
    "default": 709
  },
  "Tyrantrum": {
    "default": 697
  },
  "Tyrunt": {
    "default": 696
  },
  "Vivillon": {
    "default": 666
  },
  "Xerneas": {
    "default": 716
  },
  "Yveltal": {
    "default": 717
  },
  "Zygarde": {
    "default": 718
  }
}
