self = (if window? then window.PokeBattle.PBV ?= {} else this)

self.PokemonPBV = {
  "Arceus": {
    "default": 1001
  },
  "Mewtwo": {
    "default": 1001
  },
  "Ho-Oh": {
    "default": 1001
  },
  "Giratina": {
    "default": 1001,
    "origin": 1001
  },
  "Groudon": {
    "default": 1001
  },
  "Lugia": {
    "default": 1001
  },
  "Dialga": {
    "default": 1001
  },
  "Kyogre": {
    "default": 1001
  },
  "Rayquaza": {
    "default": 1001
  },
  "Xerneas": {
    "default": 1001
  },
  "Deoxys": {
    "attack": 1001,
    "default": 1001,
    "speed": 175,
    "defense": 165
  },
  "Reshiram": {
    "default": 1001
  },
  "Palkia": {
    "default": 1001
  },
  "Yveltal": {
    "default": 1001
  },
  "Zekrom": {
    "default": 1001
  },
  "Mew": {
    "default": 230
  },
  "Landorus": {
    "default": 225,
    "therian": 200
  },
  "Tyranitar": {
    "default": 225
  },
  "Blissey": {
    "default": 220
  },
  "Celebi": {
    "default": 215
  },
  "Salamence": {
    "default": 215
  },
  "Jirachi": {
    "default": 215
  },
  "Blaziken": {
    "default": 210
  },
  "Kyurem": {
    "white": 210,
    "black": 205,
    "default": 185
  },
  "Dragonite": {
    "default": 210
  },
  "Genesect": {
    "default": 205
  },
  "Heatran": {
    "default": 205
  },
  "Latios": {
    "default": 205
  },
  "Thundurus": {
    "default": 200,
    "therian": 170
  },
  "Darkrai": {
    "default": 200
  },
  "Latias": {
    "default": 195
  },
  "Shaymin": {
    "sky": 195,
    "default": 150
  },
  "Hydreigon": {
    "default": 195
  },
  "Registeel": {
    "default": 195
  },
  "Garchomp": {
    "default": 190
  },
  "Victini": {
    "default": 190
  },
  "Gliscor": {
    "default": 185
  },
  "Zapdos": {
    "default": 185
  },
  "Manaphy": {
    "default": 185
  },
  "Cobalion": {
    "default": 185
  },
  "Tornadus": {
    "default": 185,
    "therian": 180
  },
  "Snorlax": {
    "default": 180
  },
  "Talonflame": {
    "default": 180
  },
  "Aegislash": {
    "default": 180
  },
  "Volcarona": {
    "default": 180
  },
  "Rhyperior": {
    "default": 180
  },
  "Ditto": {
    "default": 175
  },
  "Sharpedo": {
    "default": 175
  },
  "Nidoking": {
    "default": 175
  },
  "Charizard": {
    "default": 175
  },
  "Scolipede": {
    "default": 175
  },
  "Slowking": {
    "default": 175
  },
  "Greninja": {
    "default": 170
  },
  "Togekiss": {
    "default": 170
  },
  "Reuniclus": {
    "default": 170
  },
  "Empoleon": {
    "default": 170
  },
  "Krookodile": {
    "default": 170
  },
  "Moltres": {
    "default": 170
  },
  "Azelf": {
    "default": 170
  },
  "Ninetales": {
    "default": 170
  },
  "Slowbro": {
    "default": 170
  },
  "Yanmega": {
    "default": 170
  },
  "Clefable": {
    "default": 165
  },
  "Infernape": {
    "default": 165
  },
  "Metagross": {
    "default": 165
  },
  "Crobat": {
    "default": 165
  },
  "Entei": {
    "default": 165
  },
  "Steelix": {
    "default": 165
  },
  "Meloetta": {
    "default": 165
  },
  "Noivern": {
    "default": 165
  },
  "Terrakion": {
    "default": 165
  },
  "Probopass": {
    "default": 165
  },
  "Ferrothorn": {
    "default": 160
  },
  "Nidoqueen": {
    "default": 160
  },
  "Rampardos": {
    "default": 160
  },
  "Rotom": {
    "wash": 160,
    "heat": 130,
    "fan": 115,
    "frost": 110,
    "mow": 110,
    "default": 95
  },
  "Scizor": {
    "default": 160
  },
  "Zygarde": {
    "default": 160
  },
  "Aerodactyl": {
    "default": 160
  },
  "Darmanitan": {
    "default": 160
  },
  "Gothitelle": {
    "default": 160
  },
  "Aggron": {
    "default": 155
  },
  "Arcanine": {
    "default": 155
  },
  "Aurorus": {
    "default": 155
  },
  "Chansey": {
    "default": 155
  },
  "Gyarados": {
    "default": 155
  },
  "Lucario": {
    "default": 155
  },
  "Porygon-Z": {
    "default": 155
  },
  "Tangrowth": {
    "default": 155
  },
  "Braviary": {
    "default": 155
  },
  "Articuno": {
    "default": 150
  },
  "Flygon": {
    "default": 150
  },
  "Malamar": {
    "default": 150
  },
  "Mandibuzz": {
    "default": 150
  },
  "Mr. Mime": {
    "default": 150
  },
  "Cresselia": {
    "default": 150
  },
  "Keldeo": {
    "default": 150,
    "resolute": 150
  },
  "Mamoswine": {
    "default": 150
  },
  "Mawile": {
    "default": 150
  },
  "Raikou": {
    "default": 150
  },
  "Swampert": {
    "default": 150
  },
  "Uxie": {
    "default": 150
  },
  "Excadrill": {
    "default": 150
  },
  "Gengar": {
    "default": 150
  },
  "Goodra": {
    "default": 150
  },
  "Politoed": {
    "default": 145
  },
  "Bronzong": {
    "default": 145
  },
  "Hippowdon": {
    "default": 145
  },
  "Musharna": {
    "default": 145
  },
  "Regirock": {
    "default": 145
  },
  "Suicune": {
    "default": 145
  },
  "Audino": {
    "default": 145
  },
  "Bastiodon": {
    "default": 145
  },
  "Forretress": {
    "default": 145
  },
  "Haxorus": {
    "default": 145
  },
  "Klefki": {
    "default": 145
  },
  "Machamp": {
    "default": 145
  },
  "Ninjask": {
    "default": 145
  },
  "Rhydon": {
    "default": 145
  },
  "Vaporeon": {
    "default": 145
  },
  "Carracosta": {
    "default": 145
  },
  "Roserade": {
    "default": 145
  },
  "Drifblim": {
    "default": 140
  },
  "Mesprit": {
    "default": 140
  },
  "Starmie": {
    "default": 140
  },
  "Virizion": {
    "default": 140
  },
  "Alomomola": {
    "default": 140
  },
  "Altaria": {
    "default": 140
  },
  "Chesnaught": {
    "default": 140
  },
  "Dusknoir": {
    "default": 140
  },
  "Emboar": {
    "default": 140
  },
  "Espeon": {
    "default": 140
  },
  "Gallade": {
    "default": 140
  },
  "Honchkrow": {
    "default": 140
  },
  "Lickilicky": {
    "default": 140
  },
  "Scyther": {
    "default": 140
  },
  "Skarmory": {
    "default": 140
  },
  "Staraptor": {
    "default": 140
  },
  "Stunfisk": {
    "default": 140
  },
  "Tentacruel": {
    "default": 140
  },
  "Torterra": {
    "default": 140
  },
  "Weavile": {
    "default": 140
  },
  "Alakazam": {
    "default": 140
  },
  "Sylveon": {
    "default": 140
  },
  "Azumarill": {
    "default": 135
  },
  "Feraligatr": {
    "default": 135
  },
  "Gastrodon": {
    "default": 135
  },
  "Hariyama": {
    "default": 135
  },
  "Lapras": {
    "default": 135
  },
  "Miltank": {
    "default": 135
  },
  "Zoroark": {
    "default": 135
  },
  "Ambipom": {
    "default": 135
  },
  "Archeops": {
    "default": 135
  },
  "Avalugg": {
    "default": 135
  },
  "Chandelure": {
    "default": 135
  },
  "Conkeldurr": {
    "default": 135
  },
  "Gardevoir": {
    "default": 135
  },
  "Gothorita": {
    "default": 135
  },
  "Magmortar": {
    "default": 135
  },
  "Muk": {
    "default": 135
  },
  "Shedinja": {
    "default": 135
  },
  "Tauros": {
    "default": 135
  },
  "Whimsicott": {
    "default": 135
  },
  "Xatu": {
    "default": 135
  },
  "Druddigon": {
    "default": 130
  },
  "Magnezone": {
    "default": 130
  },
  "Dugtrio": {
    "default": 130
  },
  "Electivire": {
    "default": 130
  },
  "Relicanth": {
    "default": 130
  },
  "Torkoal": {
    "default": 130
  },
  "Cradily": {
    "default": 130
  },
  "Heracross": {
    "default": 130
  },
  "Jolteon": {
    "default": 130
  },
  "Leavanny": {
    "default": 130
  },
  "Mienshao": {
    "default": 130
  },
  "Mismagius": {
    "default": 130
  },
  "Quagsire": {
    "default": 130
  },
  "Regice": {
    "default": 130
  },
  "Scrafty": {
    "default": 130
  },
  "Tyrantrum": {
    "default": 130
  },
  "Umbreon": {
    "default": 130
  },
  "Walrein": {
    "default": 130
  },
  "Breloom": {
    "default": 125
  },
  "Armaldo": {
    "default": 125
  },
  "Bisharp": {
    "default": 125
  },
  "Blastoise": {
    "default": 125
  },
  "Corsola": {
    "default": 125
  },
  "Donphan": {
    "default": 125
  },
  "Dusclops": {
    "default": 125
  },
  "Gigalith": {
    "default": 125
  },
  "Golem": {
    "default": 125
  },
  "Hawlucha": {
    "default": 125
  },
  "Houndoom": {
    "default": 125
  },
  "Hypno": {
    "default": 125
  },
  "Jellicent": {
    "default": 125
  },
  "Kabutops": {
    "default": 125
  },
  "Diggersby": {
    "default": 125
  },
  "Kecleon": {
    "default": 125
  },
  "Kingdra": {
    "default": 125
  },
  "Omastar": {
    "default": 125
  },
  "Pangoro": {
    "default": 125
  },
  "Porygon2": {
    "default": 125
  },
  "Raichu": {
    "default": 125
  },
  "Sceptile": {
    "default": 125
  },
  "Sigilyph": {
    "default": 125
  },
  "Spiritomb": {
    "default": 125
  },
  "Toxicroak": {
    "default": 125
  },
  "Medicham": {
    "default": 125
  },
  "Tropius": {
    "default": 125
  },
  "Typhlosion": {
    "default": 125
  },
  "Flareon": {
    "default": 120
  },
  "Absol": {
    "default": 120
  },
  "Ampharos": {
    "default": 120
  },
  "Barbaracle": {
    "default": 120
  },
  "Claydol": {
    "default": 120
  },
  "Cloyster": {
    "default": 120
  },
  "Cofagrigus": {
    "default": 120
  },
  "Combusken": {
    "default": 120
  },
  "Delphox": {
    "default": 120
  },
  "Drapion": {
    "default": 120
  },
  "Floatzel": {
    "default": 120
  },
  "Golurk": {
    "default": 120
  },
  "Kangaskhan": {
    "default": 120
  },
  "Kingler": {
    "default": 120
  },
  "Nosepass": {
    "default": 120
  },
  "Pyroar": {
    "default": 120
  },
  "Sableye": {
    "default": 120
  },
  "Seismitoad": {
    "default": 120
  },
  "Shiftry": {
    "default": 120
  },
  "Simisear": {
    "default": 120
  },
  "Skuntank": {
    "default": 120
  },
  "Swalot": {
    "default": 120
  },
  "Swellow": {
    "default": 120
  },
  "Throh": {
    "default": 120
  },
  "Trevenant": {
    "default": 120
  },
  "Yanma": {
    "default": 120
  },
  "Exeggutor": {
    "default": 115
  },
  "Camerupt": {
    "default": 115
  },
  "Golduck": {
    "default": 115
  },
  "Venomoth": {
    "default": 115
  },
  "Abomasnow": {
    "default": 115
  },
  "Amoonguss": {
    "default": 115
  },
  "Beheeyem": {
    "default": 115
  },
  "Cinccino": {
    "default": 115
  },
  "Garbodor": {
    "default": 115
  },
  "Golbat": {
    "default": 115
  },
  "Gothita": {
    "default": 115
  },
  "Gourgeist": {
    "super": 115,
    "small": 115,
    "large": 105,
    "default": 105
  },
  "Klinklang": {
    "default": 115
  },
  "Leafeon": {
    "default": 115
  },
  "Lunatone": {
    "default": 115
  },
  "Magcargo": {
    "default": 115
  },
  "Munchlax": {
    "default": 115
  },
  "Persian": {
    "default": 115
  },
  "Pidgeot": {
    "default": 115
  },
  "Piloswine": {
    "default": 115
  },
  "Pinsir": {
    "default": 115
  },
  "Poliwrath": {
    "default": 115
  },
  "Rapidash": {
    "default": 115
  },
  "Simipour": {
    "default": 115
  },
  "Solrock": {
    "default": 115
  },
  "Spinda": {
    "default": 115
  },
  "Venusaur": {
    "default": 115
  },
  "Volbeat": {
    "default": 115
  },
  "Wigglytuff": {
    "default": 115
  },
  "Froslass": {
    "default": 115
  },
  "Granbull": {
    "default": 115
  },
  "Lairon": {
    "default": 115
  },
  "Escavalier": {
    "default": 110
  },
  "Girafarig": {
    "default": 110
  },
  "Gligar": {
    "default": 110
  },
  "Lopunny": {
    "default": 110
  },
  "Samurott": {
    "default": 110
  },
  "Bouffalant": {
    "default": 110
  },
  "Carbink": {
    "default": 110
  },
  "Dunsparce": {
    "default": 110
  },
  "Eelektross": {
    "default": 110
  },
  "Gorebyss": {
    "default": 110
  },
  "Grumpig": {
    "default": 110
  },
  "Haunter": {
    "default": 110
  },
  "Heliolisk": {
    "default": 110
  },
  "Lanturn": {
    "default": 110
  },
  "Magmar": {
    "default": 110
  },
  "Masquerain": {
    "default": 110
  },
  "Meowstic": {
    "default": 110,
    "female": 90
  },
  "Milotic": {
    "default": 110
  },
  "Serperior": {
    "default": 110
  },
  "Slaking": {
    "default": 110
  },
  "Stantler": {
    "default": 110
  },
  "Stoutland": {
    "default": 110
  },
  "Ursaring": {
    "default": 110
  },
  "Wobbuffet": {
    "default": 110
  },
  "Crustle": {
    "default": 110
  },
  "Accelgor": {
    "default": 105
  },
  "Magneton": {
    "default": 105
  },
  "Beartic": {
    "default": 105
  },
  "Exploud": {
    "default": 105
  },
  "Hitmontop": {
    "default": 105
  },
  "Luxray": {
    "default": 105
  },
  "Qwilfish": {
    "default": 105
  },
  "Sawsbuck": {
    "default": 105
  },
  "Crawdaunt": {
    "default": 105
  },
  "Dragalge": {
    "default": 105
  },
  "Electabuzz": {
    "default": 105
  },
  "Fearow": {
    "default": 105
  },
  "Glaceon": {
    "default": 105
  },
  "Gogoat": {
    "default": 105
  },
  "Illumise": {
    "default": 105
  },
  "Jynx": {
    "default": 105
  },
  "Liepard": {
    "default": 105
  },
  "Manectric": {
    "default": 105
  },
  "Murkrow": {
    "default": 105
  },
  "Togetic": {
    "default": 105
  },
  "Trapinch": {
    "default": 105
  },
  "Weezing": {
    "default": 105
  },
  "Zangoose": {
    "default": 105
  },
  "Aromatisse": {
    "default": 105
  },
  "Mantine": {
    "default": 105
  },
  "Primeape": {
    "default": 105
  },
  "Cacturne": {
    "default": 100
  },
  "Huntail": {
    "default": 100
  },
  "Metang": {
    "default": 100
  },
  "Noctowl": {
    "default": 100
  },
  "Pignite": {
    "default": 100
  },
  "Simisage": {
    "default": 100
  },
  "Swoobat": {
    "default": 100
  },
  "Vespiquen": {
    "default": 100
  },
  "Vigoroth": {
    "default": 100
  },
  "Whiscash": {
    "default": 100
  },
  "Dewgong": {
    "default": 100
  },
  "Emolga": {
    "default": 100
  },
  "Florges": {
    "default": 100
  },
  "Frogadier": {
    "default": 100
  },
  "Galvantula": {
    "default": 100
  },
  "Kadabra": {
    "default": 100
  },
  "Misdreavus": {
    "default": 100
  },
  "Shieldon": {
    "default": 100
  },
  "Slurpuff": {
    "default": 100
  },
  "Sneasel": {
    "default": 100
  },
  "Wailord": {
    "default": 100
  },
  "Doublade": {
    "default": 100
  },
  "Sawk": {
    "default": 100
  },
  "Bibarel": {
    "default": 95
  },
  "Glalie": {
    "default": 95
  },
  "Banette": {
    "default": 95
  },
  "Heatmor": {
    "default": 95
  },
  "Hitmonlee": {
    "default": 95
  },
  "Marowak": {
    "default": 95
  },
  "Monferno": {
    "default": 95
  },
  "Purugly": {
    "default": 95
  },
  "Swanna": {
    "default": 95
  },
  "Unfezant": {
    "default": 95
  },
  "Furret": {
    "default": 95
  },
  "Gurdurr": {
    "default": 95
  },
  "Jumpluff": {
    "default": 95
  },
  "Lickitung": {
    "default": 95
  },
  "Ludicolo": {
    "default": 95
  },
  "Pupitar": {
    "default": 95
  },
  "Zebstrika": {
    "default": 95
  },
  "Cranidos": {
    "default": 90
  },
  "Diglett": {
    "default": 90
  },
  "Dodrio": {
    "default": 90
  },
  "Ferroseed": {
    "default": 90
  },
  "Hitmonchan": {
    "default": 90
  },
  "Klang": {
    "default": 90
  },
  "Octillery": {
    "default": 90
  },
  "Omanyte": {
    "default": 90
  },
  "Pelipper": {
    "default": 90
  },
  "Regigigas": {
    "default": 90
  },
  "Sandslash": {
    "default": 90
  },
  "Sudowoodo": {
    "default": 90
  },
  "Tangela": {
    "default": 90
  },
  "Tirtouga": {
    "default": 90
  },
  "Charmeleon": {
    "default": 90
  },
  "Clawitzer": {
    "default": 90
  },
  "Fletchinder": {
    "default": 90
  },
  "Marshtomp": {
    "default": 90
  },
  "Raticate": {
    "default": 90
  },
  "Arbok": {
    "default": 90
  },
  "Chatot": {
    "default": 90
  },
  "Cryogonal": {
    "default": 90
  },
  "Duosion": {
    "default": 90
  },
  "Furfrou": {
    "default": 90
  },
  "Graveler": {
    "default": 90
  },
  "Lumineon": {
    "default": 90
  },
  "Scraggy": {
    "default": 90
  },
  "Vileplume": {
    "default": 90
  },
  "Ariados": {
    "default": 85
  },
  "Beedrill": {
    "default": 85
  },
  "Bellossom": {
    "default": 85
  },
  "Phione": {
    "default": 85
  },
  "Rhyhorn": {
    "default": 85
  },
  "Slowpoke": {
    "default": 85
  },
  "Watchog": {
    "default": 85
  },
  "Zweilous": {
    "default": 85
  },
  "Aron": {
    "default": 85
  },
  "Porygon": {
    "default": 85
  },
  "Wynaut": {
    "default": 85
  },
  "Basculin": {
    "default": 85,
    "red-striped": 85
  },
  "Bronzor": {
    "default": 85
  },
  "Gabite": {
    "default": 85
  },
  "Ledian": {
    "default": 85
  },
  "Meganium": {
    "default": 85
  },
  "Mime Jr.": {
    "default": 85
  },
  "Roselia": {
    "default": 85
  },
  "Seadra": {
    "default": 85
  },
  "Sealeo": {
    "default": 85
  },
  "Shelgon": {
    "default": 85
  },
  "Vanilluxe": {
    "default": 85
  },
  "Victreebel": {
    "default": 85
  },
  "Vivillon": {
    "default": 85
  },
  "Wormadam": {
    "sandy": 85,
    "trash": 75,
    "default": 70
  },
  "Butterfree": {
    "default": 80
  },
  "Magnemite": {
    "default": 80
  },
  "Dustox": {
    "default": 80
  },
  "Grotle": {
    "default": 80
  },
  "Lampent": {
    "default": 80
  },
  "Linoone": {
    "default": 80
  },
  "Machoke": {
    "default": 80
  },
  "Minun": {
    "default": 80
  },
  "Onix": {
    "default": 80
  },
  "Seviper": {
    "default": 80
  },
  "Carvanha": {
    "default": 80
  },
  "Seaking": {
    "default": 80
  },
  "Shuckle": {
    "default": 80
  },
  "Chimecho": {
    "default": 80
  },
  "Clefairy": {
    "default": 80
  },
  "Delcatty": {
    "default": 80
  },
  "Farfetch'd": {
    "default": 80
  },
  "Kabuto": {
    "default": 80
  },
  "Krabby": {
    "default": 80
  },
  "Krokorok": {
    "default": 80
  },
  "Lileep": {
    "default": 80
  },
  "Mightyena": {
    "default": 80
  },
  "Mothim": {
    "default": 80
  },
  "Parasect": {
    "default": 80
  },
  "Meditite": {
    "default": 80
  },
  "Plusle": {
    "default": 80
  },
  "Prinplup": {
    "default": 80
  },
  "Swadloon": {
    "default": 80
  },
  "Vullaby": {
    "default": 80
  },
  "Whirlipede": {
    "default": 80
  },
  "Croconaw": {
    "default": 75
  },
  "Dragonair": {
    "default": 75
  },
  "Duskull": {
    "default": 75
  },
  "Fraxure": {
    "default": 75
  },
  "Koffing": {
    "default": 75
  },
  "Mienfoo": {
    "default": 75
  },
  "Natu": {
    "default": 75
  },
  "Pawniard": {
    "default": 75
  },
  "Quilladin": {
    "default": 75
  },
  "Staryu": {
    "default": 75
  },
  "Torchic": {
    "default": 75
  },
  "Rufflet": {
    "default": 75
  },
  "Aipom": {
    "default": 75
  },
  "Amaura": {
    "default": 75
  },
  "Boldore": {
    "default": 75
  },
  "Castform": {
    "default": 75
  },
  "Drifloon": {
    "default": 75
  },
  "Electrode": {
    "default": 75
  },
  "Inkay": {
    "default": 75
  },
  "Larvesta": {
    "default": 75
  },
  "Lilligant": {
    "default": 75
  },
  "Maractus": {
    "default": 75
  },
  "Ponyta": {
    "default": 75
  },
  "Sliggoo": {
    "default": 75
  },
  "Solosis": {
    "default": 75
  },
  "Tyrunt": {
    "default": 75
  },
  "Wartortle": {
    "default": 75
  },
  "Anorith": {
    "default": 70
  },
  "Beautifly": {
    "default": 70
  },
  "Frillish": {
    "default": 70
  },
  "Gastly": {
    "default": 70
  },
  "Geodude": {
    "default": 70
  },
  "Staravia": {
    "default": 70
  },
  "Tentacool": {
    "default": 70
  },
  "Vibrava": {
    "default": 70
  },
  "Yamask": {
    "default": 70
  },
  "Carnivine": {
    "default": 70
  },
  "Dewott": {
    "default": 70
  },
  "Elgyem": {
    "default": 70
  },
  "Grimer": {
    "default": 70
  },
  "Magby": {
    "default": 70
  },
  "Sunflora": {
    "default": 70
  },
  "Abra": {
    "default": 70
  },
  "Archen": {
    "default": 70
  },
  "Bagon": {
    "default": 70
  },
  "Buneary": {
    "default": 70
  },
  "Dedenne": {
    "default": 70
  },
  "Eelektrik": {
    "default": 70
  },
  "Grovyle": {
    "default": 70
  },
  "Hippopotas": {
    "default": 70
  },
  "Honedge": {
    "default": 70
  },
  "Larvitar": {
    "default": 70
  },
  "Quilava": {
    "default": 70
  },
  "Swablu": {
    "default": 70
  },
  "Vulpix": {
    "default": 70
  },
  "Mantyke": {
    "default": 65
  },
  "Corphish": {
    "default": 65
  },
  "Cubone": {
    "default": 65
  },
  "Durant": {
    "default": 130
  },
  "Elekid": {
    "default": 65
  },
  "Gloom": {
    "default": 65
  },
  "Growlithe": {
    "default": 65
  },
  "Ivysaur": {
    "default": 65
  },
  "Klink": {
    "default": 65
  },
  "Litwick": {
    "default": 65
  },
  "Nidorino": {
    "default": 65
  },
  "Pikachu": {
    "default": 65
  },
  "Poliwhirl": {
    "default": 65
  },
  "Pumpkaboo": {
    "default": 65,
    "small": 65,
    "large": 65,
    "super": 65
  },
  "Servine": {
    "default": 65
  },
  "Wailmer": {
    "default": 65
  },
  "Baltoy": {
    "default": 65
  },
  "Binacle": {
    "default": 65
  },
  "Braixen": {
    "default": 65
  },
  "Cherrim": {
    "default": 65
  },
  "Drowzee": {
    "default": 65
  },
  "Dwebble": {
    "default": 65
  },
  "Golett": {
    "default": 65
  },
  "Houndour": {
    "default": 65
  },
  "Kricketune": {
    "default": 65
  },
  "Litleo": {
    "default": 65
  },
  "Loudred": {
    "default": 65
  },
  "Pancham": {
    "default": 65
  },
  "Phantump": {
    "default": 65
  },
  "Pidgeotto": {
    "default": 65
  },
  "Pineco": {
    "default": 65
  },
  "Sewaddle": {
    "default": 65
  },
  "Shelmet": {
    "default": 65
  },
  "Skrelp": {
    "default": 65
  },
  "Snubbull": {
    "default": 65
  },
  "Spritzee": {
    "default": 65
  },
  "Timburr": {
    "default": 65
  },
  "Charmander": {
    "default": 60
  },
  "Flaaffy": {
    "default": 60
  },
  "Bonsly": {
    "default": 60
  },
  "Cacnea": {
    "default": 60
  },
  "Chimchar": {
    "default": 60
  },
  "Deino": {
    "default": 60
  },
  "Froakie": {
    "default": 60
  },
  "Herdier": {
    "default": 60
  },
  "Luxio": {
    "default": 60
  },
  "Meowth": {
    "default": 60
  },
  "Munna": {
    "default": 60
  },
  "Nidorina": {
    "default": 60
  },
  "Numel": {
    "default": 60
  },
  "Nuzleaf": {
    "default": 60
  },
  "Riolu": {
    "default": 60
  },
  "Skorupi": {
    "default": 60
  },
  "Swirlix": {
    "default": 60
  },
  "Tepig": {
    "default": 60
  },
  "Togepi": {
    "default": 60
  },
  "Trubbish": {
    "default": 60
  },
  "Axew": {
    "default": 60
  },
  "Chespin": {
    "default": 60
  },
  "Croagunk": {
    "default": 60
  },
  "Darumaka": {
    "default": 60
  },
  "Gulpin": {
    "default": 60
  },
  "Kirlia": {
    "default": 60
  },
  "Palpitoad": {
    "default": 60
  },
  "Phanpy": {
    "default": 60
  },
  "Piplup": {
    "default": 60
  },
  "Psyduck": {
    "default": 60
  },
  "Sandile": {
    "default": 60
  },
  "Sandshrew": {
    "default": 60
  },
  "Shellder": {
    "default": 60
  },
  "Shellos": {
    "default": 60
  },
  "Spoink": {
    "default": 60
  },
  "Squirtle": {
    "default": 60
  },
  "Totodile": {
    "default": 60
  },
  "Turtwig": {
    "default": 60
  },
  "Woobat": {
    "default": 60
  },
  "Zorua": {
    "default": 60
  },
  "Bayleef": {
    "default": 55
  },
  "Bergmite": {
    "default": 55
  },
  "Chinchou": {
    "default": 55
  },
  "Clamperl": {
    "default": 55
  },
  "Cottonee": {
    "default": 55
  },
  "Delibird": {
    "default": 55
  },
  "Drilbur": {
    "default": 55
  },
  "Exeggcute": {
    "default": 55
  },
  "Floette": {
    "default": 55
  },
  "Gible": {
    "default": 55
  },
  "Lombre": {
    "default": 55
  },
  "Machop": {
    "default": 55
  },
  "Mankey": {
    "default": 55
  },
  "Mudkip": {
    "default": 55
  },
  "Pachirisu": {
    "default": 55
  },
  "Paras": {
    "default": 55
  },
  "Seel": {
    "default": 55
  },
  "Shuppet": {
    "default": 55
  },
  "Skiploom": {
    "default": 55
  },
  "Snover": {
    "default": 55
  },
  "Stunky": {
    "default": 55
  },
  "Teddiursa": {
    "default": 55
  },
  "Vanillish": {
    "default": 55
  },
  "Venonat": {
    "default": 55
  },
  "Weepinbell": {
    "default": 55
  },
  "Buizel": {
    "default": 55
  },
  "Bulbasaur": {
    "default": 55
  },
  "Dratini": {
    "default": 55
  },
  "Ekans": {
    "default": 55
  },
  "Finneon": {
    "default": 55
  },
  "Foongus": {
    "default": 55
  },
  "Jigglypuff": {
    "default": 55
  },
  "Ledyba": {
    "default": 55
  },
  "Oddish": {
    "default": 55
  },
  "Pansear": {
    "default": 55
  },
  "Shroomish": {
    "default": 55
  },
  "Smoochum": {
    "default": 55
  },
  "Spinarak": {
    "default": 55
  },
  "Taillow": {
    "default": 55
  },
  "Tranquill": {
    "default": 55
  },
  "Budew": {
    "default": 55
  },
  "Chingling": {
    "default": 55
  },
  "Deerling": {
    "default": 55
  },
  "Marill": {
    "default": 55
  },
  "Purrloin": {
    "default": 55
  },
  "Clauncher": {
    "default": 50
  },
  "Eevee": {
    "default": 50
  },
  "Fletchling": {
    "default": 50
  },
  "Goldeen": {
    "default": 50
  },
  "Horsea": {
    "default": 50
  },
  "Makuhita": {
    "default": 50
  },
  "Minccino": {
    "default": 50
  },
  "Nidoran♂": {
    "default": 50
  },
  "Oshawott": {
    "default": 50
  },
  "Panpour": {
    "default": 50
  },
  "Skiddo": {
    "default": 50
  },
  "Slugma": {
    "default": 50
  },
  "Spheal": {
    "default": 50
  },
  "Venipede": {
    "default": 50
  },
  "Bidoof": {
    "default": 50
  },
  "Espurr": {
    "default": 50
  },
  "Remoraid": {
    "default": 50
  },
  "Roggenrola": {
    "default": 50
  },
  "Skitty": {
    "default": 50
  },
  "Doduo": {
    "default": 50
  },
  "Glameow": {
    "default": 50
  },
  "Joltik": {
    "default": 50
  },
  "Spearow": {
    "default": 50
  },
  "Wingull": {
    "default": 50
  },
  "Wooper": {
    "default": 50
  },
  "Bunnelby": {
    "default": 50
  },
  "Barboach": {
    "default": 45
  },
  "Chikorita": {
    "default": 45
  },
  "Cleffa": {
    "default": 45
  },
  "Cubchoo": {
    "default": 45
  },
  "Cyndaquil": {
    "default": 45
  },
  "Ducklett": {
    "default": 45
  },
  "Electrike": {
    "default": 45
  },
  "Fennekin": {
    "default": 45
  },
  "Flabébé": {
    "default": 45
  },
  "Goomy": {
    "default": 45
  },
  "Helioptile": {
    "default": 45
  },
  "Karrablast": {
    "default": 45
  },
  "Nidoran♀": {
    "default": 45
  },
  "Noibat": {
    "default": 45
  },
  "Pidgey": {
    "default": 45
  },
  "Sentret": {
    "default": 45
  },
  "Snivy": {
    "default": 45
  },
  "Surskit": {
    "default": 45
  },
  "Swinub": {
    "default": 45
  },
  "Treecko": {
    "default": 45
  },
  "Zubat": {
    "default": 45
  },
  "Poliwag": {
    "default": 45
  },
  "Vanillite": {
    "default": 45
  },
  "Hoothoot": {
    "default": 45
  },
  "Hoppip": {
    "default": 45
  },
  "Pansage": {
    "default": 45
  },
  "Patrat": {
    "default": 45
  },
  "Shinx": {
    "default": 45
  },
  "Smeargle": {
    "default": 80
  },
  "Voltorb": {
    "default": 45
  },
  "Bellsprout": {
    "default": 40
  },
  "Lillipup": {
    "default": 40
  },
  "Mareep": {
    "default": 40
  },
  "Pidove": {
    "default": 40
  },
  "Ralts": {
    "default": 40
  },
  "Rattata": {
    "default": 40
  },
  "Snorunt": {
    "default": 40
  },
  "Starly": {
    "default": 40
  },
  "Luvdisc": {
    "default": 40
  },
  "Whismur": {
    "default": 40
  },
  "Blitzle": {
    "default": 35
  },
  "Cherubi": {
    "default": 35
  },
  "Nincada": {
    "default": 35
  },
  "Poochyena": {
    "default": 35
  },
  "Seedot": {
    "default": 35
  },
  "Azurill": {
    "default": 35
  },
  "Happiny": {
    "default": 35
  },
  "Lotad": {
    "default": 35
  },
  "Petilil": {
    "default": 35
  },
  "Pichu": {
    "default": 35
  },
  "Zigzagoon": {
    "default": 35
  },
  "Igglybuff": {
    "default": 30
  },
  "Tyrogue": {
    "default": 30
  },
  "Tympole": {
    "default": 30
  },
  "Slakoth": {
    "default": 30
  },
  "Sunkern": {
    "default": 25
  },
  "Feebas": {
    "default": 20
  },
  "Beldum": {
    "default": 15
  },
  "Combee": {
    "default": 10
  },
  "Cascoon": {
    "default": 10
  },
  "Metapod": {
    "default": 10
  },
  "Silcoon": {
    "default": 10
  },
  "Spewpa": {
    "default": 10
  },
  "Tynamo": {
    "default": 10
  },
  "Kakuna": {
    "default": 5
  },
  "Burmy": {
    "default": 5
  },
  "Caterpie": {
    "default": 5
  },
  "Kricketot": {
    "default": 5
  },
  "Magikarp": {
    "default": 5
  },
  "Scatterbug": {
    "default": 5
  },
  "Unown": {
    "default": 5
  },
  "Weedle": {
    "default": 5
  },
  "Wurmple": {
    "default": 5
  }
}

self.ItemPBV = {
  "Blazikenite": 85,
  "Tyranitarite": 45,
  "Charizardite Y": 85,
  "Gengarite": 105,
  "Kangaskhanite": 105,
  "Lucarionite": 70,
  "Garchompite": 25,
  "Charizardite X": 35,
  "Mawilite": 55,
  "Aggronite": 45,
  "Scizorite": 40,
  "Medichamite": 70,
  "Gardevoirite": 45,
  "Absolite": 70,
  "Aerodactylite": 25,
  "Venusaurite": 60,
  "Gyaradosite": 10,
  "Houndoominite": 35,
  "Alakazite": 10,
  "Ampharosite": 25,
  "Blastoisinite": 20,
  "Abomasite": 30,
  "Banettite": 50,
  "Pinsirite": 30,
  "Manectite": 35,
  "Heracronite": 5,
  "Mewtwonite X": 0,
  "Mewtwonite Y": 0
}

self.determinePBV = (pokemonArray) ->
  if pokemonArray not instanceof Array then pokemonArray = [ pokemonArray ]
  total = 0
  for pokemon in pokemonArray
    species = pokemon.name
    forme = pokemon.forme || "default"
    item = pokemon.item
    total += self.PokemonPBV[species]?[forme] || 0
    total += self.ItemPBV[item] || 0
  return total
