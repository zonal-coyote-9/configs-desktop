#!/usr/bin/env python3
"""Password Generator - an interactive command-line tool for generating
strong, unique passwords (random-character or memorable/word-based),
with a rough security score and crack-time estimate.

Two modes:
  Random     - a string of random characters (letters/numbers/symbols).
  Memorable  - a sequence of dictionary words, e.g. Banjo6-Reprogram5-Clambake2

Adjustable: length or word count, capital letters, numbers, symbols,
and separator style. Also prints a handful of alternate passwords and
a strength rating with an estimated time-to-crack.

Examples:
  python generate_password.py
      Launches the interactive menu (Memorable mode by default).

  python generate_password.py --non-interactive --mode Random --length 20 --count 5
      Prints 5 random 20-character passwords and exits.

  python generate_password.py --non-interactive --mode Memorable --substitutions --count 5
      Prints 5 passwords like "Cl3v3r-F4lc0n7-M1dn1ght2" and exits.
"""

import argparse
import math
import os
import secrets
import string
import time
from dataclasses import dataclass

# ---------------------------------------------------------------------------
# Word list (for Memorable mode)
# ---------------------------------------------------------------------------

WORD_LIST = (
    'brave','calm','clever','cosmic','crimson','curious','dapper','daring','dizzy','eager',
    'electric','fierce','fluffy','frosty','gentle','golden','happy','hidden','icy','jolly',
    'jumpy','lively','lucky','mighty','misty','mystic','nimble','plucky','quiet','quirky',
    'rapid','rusty','sharp','shiny','silent','silly','sleepy','smoky','snappy','sneaky',
    'solar','sparky','spry','stellar','stormy','sunny','swift','tidy','witty','wild',
    'zesty','breezy','chill','cozy','epic','feral','grumpy','honest','jazzy','ancient',
    'arctic','azure','bionic','blazing','bold','bouncy','bubbly','bumpy','burly','candid',
    'carefree','cheeky','chirpy','chunky','classy','cloudy','coastal','coral','crafty','creaky',
    'crisp','crooked','crunchy','crystal','cuddly','dashing','dawning','defiant','devout','dreamy',
    'drowsy','dusty','earthy','elegant','emerald','enchanted','endless','evasive','expert','faded',
    'faint','famous','fearless','fizzy','flashy','fleeting','flickering','floral','foamy','foggy',
    'fragrant','frantic','frozen','fuzzy','gallant','gigantic','glassy','gleaming','glossy','graceful',
    'grand','gritty','groovy','hardy','harmless','hasty','hazy','heroic','hollow','humble',
    'hushed','hyper','idle','impish','indigo','infinite','inky','ivory','jagged','jaunty',
    'jubilant','keen','knobby','lanky','legendary','lofty','lonely','loud','loyal','lush',
    'magnetic','majestic','marbled','massive','melodic','mellow','merry','metallic','minty','modest',
    'moonlit','muddy','murky','musical','narrow','neat','nifty','noble','nocturnal','oaken',
    'obsidian','odd','olive','opal','orbital','ornate','pastel','peaceful','peppy','perky',
    'petite','pixelated','placid','playful','plump','polar','polished','posh','prickly','proud',
    'punchy','radiant','ragged','rambling','rare','regal','restless','ripe','robust','rogue',
    'rowdy','royal','rugged','rumbling','sable','salty','sandy','savage','scarlet','scrappy',
    'scruffy','serene','shadowy','shaggy','shallow','shimmering','shrewd','sizzling','skittish','slick',
    'slippery','smooth','snug','soaring','sonic','sparkling','speckled','spicy','spirited','splendid',
    'spooky','spotless','springy','squishy','stalwart','steady','stealthy','sturdy','subtle','supreme',
    'swanky','tangled','tenacious','thorny','thrifty','thundering','tidal','timid','tiny','toasty',
    'towering','tranquil','trusty','tumbling','turbo','twilight','twinkling','unruly','valiant','velvet',
    'vibrant','vintage','vivid','wandering','warm','weathered','whimsical','windy','wispy','wobbly',
    'wondrous','woolly','zany','zippy','badger','beacon','cobra','comet','condor','coyote',
    'crane','dolphin','dragon','eagle','ember','falcon','ferret','glacier','gopher','griffin',
    'harbor','hawk','heron','jaguar','kestrel','kite','koala','lantern','lemur','lynx',
    'magpie','maple','meteor','moose','nebula','ocelot','orchid','otter','panther','panda',
    'phoenix','pixel','planet','puma','quokka','raven','reef','rocket','shadow','sparrow',
    'tiger','viper','willow','wolf','wombat','zephyr','canyon','cascade','citadel','forge',
    'summit','anchor','antler','arbor','archer','arrow','asteroid','atlas','aurora','avalanche',
    'banner','baron','basin','blizzard','bluff','bonfire','boulder','breeze','bridge','brook',
    'cabin','cactus','cairn','campfire','canvas','canopy','castle','cavern','cedar','chalice',
    'chariot','cinder','cipher','circuit','citrus','cliff','clover','cobalt','compass',
    'cottage','crater','creek','crescent','crown','current','cypress','delta','desert','diamond',
    'dune','dusk','dynamo','eclipse','engine','envoy','equinox','estuary','fable','falls',
    'fern','firefly','fjord','flame','flare','flint','fossil','fountain','frontier','galaxy',
    'garnet','geyser','glade','glider','glimmer','globe','granite','gravel','grove','gully',
    'halo','hammer','harvest','haven','hemlock','horizon','hurricane','hydra','iceberg','igloo',
    'inferno','island','jasper','jungle','keystone','kingdom','labyrinth','lagoon','landmark','laser',
    'ledge','legion','lightning','lodge','longbow','lumen','magnet','mammoth','mantle','marble',
    'marsh','matrix','mesa','meridian','mirage','mirror','monolith','monsoon','moonbeam','mosaic',
    'mountain','nectar','needle','nova','nucleus','oasis','obelisk','onyx','orbit','origin',
    'outpost','oxide','pagoda','palisade','pathway','peak','pebble','pendant','pinnacle','pioneer',
    'plateau','portal','prairie','prism','prowler','pulsar','quarry','quartz','quest','quiver',
    'radar','rampart','rapids','ravine','realm','reservoir','rhythm','ridge','rift','ripple',
    'riverbank','rune','saga','sanctuary','satellite','savanna','scepter','schooner','scout','sentinel',
    'sequoia','shard','shore','shrine','signal','silo','skiff','skyline','slate','sleigh',
    'solstice','spectrum','sphinx','spire','spore','spruce','stallion','starfall','statue','steppe',
    'strait','stronghold','sundial','surge','swamp','tempest','terrace','thicket','thistle','thunder',
    'tidepool','timber','torch','totem','trailblazer','trek','trench','trestle','trident','tundra',
    'turret','tusk','twister','undertow','vagabond','valley','vanguard','vantage','vapor','vault',
    'velocity','vertex','vessel','vineyard','vista','volcano','vortex','voyage','warden','waterfall',
    'wharf','whirlpool','wildfire','wilderness','windmill','wingman','wisp','wizard','wraith','yeti',
    'zenith','zodiac','blazes','bolts','chases','climbs','dances','darts','dashes','dives',
    'drifts','drives','explores','flies','floats','glides','gallops','glows','hops','hunts',
    'jumps','leaps','lurks','prowls','races','roams','roars','rolls','sails','sneaks',
    'soars','sparks','spins','sprints','stalks','surges','swims','swoops','trots','wanders',
    'zooms','builds','carves','charges','crafts','dreams','flows','forges','ignites','shines',
    'ascends','awakens','balances','bends','bounces','breaks','bristles','bursts','captures','careens',
    'catapults','circles','clashes','coasts','collides','conjures','conquers','creeps','crosses','crumbles',
    'cruises','crushes','defends','defies','delivers','descends','detects','devours','discovers','doubles',
    'echoes','emerges','endures','erupts','escapes','evolves','expands','fades','fights',
    'flares','flashes','flickers','flutters','forages','gathers','generates','glimmers','glistens','governs',
    'grabs','grinds','grips','grows','guards','guides','hammers','harnesses','haunts','hides',
    'hikes','holds','howls','hovers','hums','hurls','inspires','invents','journeys','juggles',
    'kindles','launches','leads','leaks','learns','levitates','lifts','lights','lingers','locks',
    'looms','lunges','maneuvers','marches','masters','meanders','merges','migrates','mines','multiplies',
    'navigates','nests','oscillates','outruns','paddles','patrols','pierces','pilots','plants','plots',
    'plunges','ponders','pounces','powers','presses','probes','projects','propels','protects','pulses',
    'pursues','quakes','radiates','rallies','reaches','rebounds','reflects','releases','resonates','rests',
    'reveals','rides','rises','rockets','rumbles','scales','scans','scatters','scours','searches',
    'seeks','shapes','shatters','shields','shifts','shovels','signals','simmers','sings','skates',
    'sketches','skips','skirts','slides','slinks','slithers','smolders','snaps','snoops','solves',
    'spans','sprouts','stampedes','steers','stirs','stomps','streaks','strides','strikes','strolls',
    'summons','surfs','surveys','sweeps','swerves','swirls','tackles','tames','tangles','targets',
    'thrives','thrusts','tilts','tinkers','towers','traces','tracks','trails','transforms','traverses',
    'treks','trembles','triggers','triumphs','trudges','tumbles','tunnels','twirls','unfolds','unleashes',
    'unlocks','unwinds','vaults','ventures','vibrates','voyages','wades','wakes','watches','weaves',
    'whirls','whistles','wields','winds','wraps','clambake','banjo','reprogram','spud','womankind',
    'sludge','sanctity','retiring','sadly','upload','gloss','retorted','exponent','mummify','crummiest',
    'glandular','hangnail','remake','kiwi','prewar','immerse','alongside','undivided','delivery','sanded',
    'grandpa','ship','devotee','salaried',
    'sly','deep','forgotten','glimmering','holographic','knightly','midnight','nostalgic','outlandish','soft',
    'steel','ultra','wry','young','zonal','zealous','fox','continent','gyro','ivy',
    'jetstream','jupiter','ley','lunar','mist','mosswood','overlook','wavelength','wreck','runs',
    'calculates','dodges','draws','drums','flips','moves','james','john','robert','michael',
    'william','david','richard','joseph','thomas','charles','christopher','daniel','matthew','anthony',
    'mark','donald','steven','paul','andrew','joshua','kenneth','kevin','brian','george',
    'edward','ronald','timothy','jason','jeffrey','ryan','jacob','gary','nicholas','eric',
    'jonathan','stephen','larry','justin','scott','brandon','benjamin','samuel','gregory','alexander',
    'patrick','frank','raymond','jack','dennis','jerry','tyler','aaron','jose','adam',
    'nathan','henry','douglas','zachary','peter','kyle','walter','ethan','jeremy','harold',
    'keith','christian','roger','noah','gerald','carl','terry','sean','austin','arthur',
    'lawrence','jesse','dylan','bryan','joe','billy','bruce','albert','willie','gabriel',
    'logan','alan','juan','wayne','roy','ralph','randy','eugene','vincent','russell',
    'elijah','louis','bobby','philip','johnny','mason','mary','patricia','jennifer','linda',
    'elizabeth','barbara','susan','jessica','sarah','karen','nancy','lisa','margaret','betty',
    'sandra','ashley','dorothy','kimberly','emily','donna','michelle','carol','amanda','melissa',
    'deborah','stephanie','rebecca','sharon','laura','cynthia','kathleen','amy','angela','shirley',
    'anna','brenda','pamela','emma','nicole','helen','samantha','katherine','christine','debra',
    'rachel','carolyn','janet','maria','heather','diane','julie','joyce','victoria','kelly',
    'christina','lauren','joan','evelyn','olivia','judith','megan','cheryl','martha','andrea',
    'frances','hannah','jacqueline','ann','gloria','jean','kathryn','alice','teresa','sara',
    'janice','doris','madison','julia','grace','judy','abigail','marie','denise','beverly',
    'amber','theresa','marilyn','danielle','diana','brittany','natalie','sophia','rose','isabella',
    'alexis','kayla','charlotte','taylor','morgan','casey','riley','avery','peyton','quinn',
    'skyler','cameron','reese','rowan','sage','dakota','emerson','finley','harper','hayden',
    'jamie','kendall','marley','parker','river','robin','shawn','sydney','blair','charlie',
    'quantum','cryptic','cybernetic','digital','atomic','molecular','galactic','interstellar','plasma','photon',
    'neutron','proton','electron','isotope','reactor','turbine','catalyst','voltage','frequency','android',
    'robot','cyborg','drone','telescope','microscope','sensor','scanner','terminal','console','firewall',
    'gateway','network','server','protocol','algorithm','encryption','decryption','binary','vector','polygon',
    'fractal','spiral','helix','quasar','supernova','blackhole','wormhole','singularity','nadir','corona',
    'gravity','momentum','inertia','friction','magnetism','polarity','chimera','minotaur','centaur','pegasus',
    'unicorn','basilisk','wyvern','golem','banshee','valkyrie','oracle','seer','sorcerer','warlock',
    'druid','paladin','ranger','bard','monk','cleric','alchemist','artificer','enchanter','shaman',
    'prophet','herald','keeper','watcher','nomad','pilgrim','voyager','explorer','settler','colonist',
    'pathfinder','cinnamon','saffron','paprika','basil','thyme','rosemary','lavender','jasmine','lotus',
    'tulip','daisy','marigold','sunflower','moss','lichen','bamboo','birch','pine','redwood',
    'aspen','elm','oak','mahogany','ebony','teak','walnut','chestnut','hazelnut','almond',
    'pistachio','cashew','pecan','apricot','peach','plum','cherry','mango','papaya','guava',
    'pineapple','coconut','cranberry','blueberry','raspberry','blackberry','strawberry','watermelon','cantaloupe','honeydew',
    'nectarine','tangerine','clementine','grapefruit','pomegranate','vermillion','magenta','fuchsia','periwinkle','turquoise',
    'teal','cerulean','sapphire','ruby','amethyst','topaz','alabaster','limestone','sandstone','basalt',
    'pumice','shale','gneiss','quartzite','typhoon','tornado','whirlwind','thunderbolt','downpour','drizzle',
    'fog','haze','dew','rime','sleet','hail','snowflake','icicle','permafrost','ash',
    'smoke','soot','rainforest','wetland','floodplain','watershed','aquifer','tributary','confluence','meander',
    'oxbow','floodgate','dam','levee','dike','causeway','viaduct','aqueduct','cistern','hotspring',
    'thermal','archipelago','peninsula','isthmus','atoll','butte','taiga','savannah','gecko','iguana',
    'chameleon','salamander','newt','toad','frog','cricket','beetle','dragonfly','butterfly','moth',
    'ladybug','spider','centipede','millipede','snail','slug','jellyfish','starfish','seahorse','octopus',
    'squid','crab','lobster','clam','oyster','satin','silk','denim','burlap','cashmere',
    'alpaca','chrome','titanium','platinum','copper','bronze','brass','ceramic','porcelain','gauge',
    'dial','lever','pulley','gear','cog','piston','cylinder','chamber','archive','ledger',
    'tome','scroll','parchment','quill','inkwell','manuscript','codex','chronicle','almanac','cartograph',
    'latitude','longitude','equator','tropic','hemisphere',
    'agile','ample','bashful','blithe','bright','brisk','buoyant','cheery','chipper','civil',
    'coy','crafted','deft','dewy','dim','droll','dusky','feisty','fervent','fiery',
    'flinty','frisky','gaudy','giddy','glad','gleeful','gutsy','hearty','hefty','hoary',
    'humid','jovial','lavish','limber','lithe','lucid','marshy','mirthful','moody','mossy',
    'nautical','nippy','patient','pearly','pensive','plush','poised','quaint','quick','rosy',
    'rustic','sassy','sedate','shy','sleek','smart','sober','spiffy','spunky','starry',
    'steamy','stout','sugary','swell','tawny','tepid','tough','tricky','trim','upbeat',
    'urban','verdant','vocal','wary','wavy','wintry','abacus','acorn','adder','albatross',
    'alcove','anvil','apex','aqueous','armada','armory','avenue','axle','bayou','beagle',
    'bellows','blossom','bobcat','bolt','bramble','brigade','bugle','bungalow','burrow','buttress',
    'caboose','camel','caravan','caribou','carousel','catamaran','chimney','cirrus','clipper','cobble',
    'cockpit','cougar','courier','cumulus','dagger','dory','dynasty','egret','elk','emu',
    'fiddle','finch','flagship','flotilla','foxglove','galleon','gazelle','gondola','gorge','granary',
    'gull','hamlet','harpoon','hatchet','hearth','hedgehog','hilltop','hornet','husky','ibis',
    'jackal','jetty','kayak','kelp','kettle','lattice','lilac','lighthouse','llama','locket',
    'lookout','mallard','manor','mariner','marten','mill','minnow','mongoose','moor','narwhal',
    'orca','osprey','outback','paddock','parapet','penguin','pewter','pheasant','pier','pond',
    'puffin','python','quail','raccoon','reindeer','rook','saddle','sandbar','sawmill','seal',
    'shipyard','skylark','sloop','snowdrift','stag','starling','stockade','stork','sycamore','tanager',
    'thatch','toucan','trawler','trellis','tugboat','turtle','valve','vole','walrus','warbler',
    'weasel','whale','wren','yacht','zebra','babbles','basks','beams','blinks','bobs',
    'booms','bows','braves','brews','canters','chants','chimes','chirps','clatters','crackles',
    'cranks','croons','dabbles','dawdles','dips','ebbs','edges','fetches','flings','flourishes',
    'fumbles','gleams','glints','greets','gusts','hoists','hurries','jests','jogs','kneads',
    'knits','lopes','lulls','mingles','muses','nudges','orbits','paces','perches','pivots',
    'plays','prances','purrs','rambles','rattles','roves','rustles','saunters','scurries','skims',
    'sleds','slips','snoozes','sprawls','sputters','squawks','stumbles','swaggers','tiptoes','toddles',
    'toots','trills','trundles','twitches','waddles','whirs','whooshes','wiggles','yodels','zigzags',
)

# ---------------------------------------------------------------------------
# Character sets (for Random mode)
# ---------------------------------------------------------------------------

LOWER_CHARS = string.ascii_lowercase
UPPER_CHARS = string.ascii_uppercase
DIGIT_CHARS = string.digits
SYMBOL_CHARS = '!@#$%^&*()-_=+[]{};:,.<>/?'

# Leetspeak-style number/symbol substitutions (lowercase letters only, so a
# capitalized first letter is left alone and still reads as a real word).
SUBSTITUTION_MAP = {
    'a': '@', 'b': '8', 'e': '3', 'g': '9', 'i': '1',
    'l': '!', 'o': '0', 's': '$', 't': '7', 'z': '2',
}

SEPARATORS = {
    'Hyphens': '-',
    'Underscores': '_',
    'Dots': '.',
    'Spaces': ' ',
    'None': '',
}

COLORS = {
    'Red': '\033[91m',
    'Green': '\033[92m',
    'Yellow': '\033[93m',
    'DarkYellow': '\033[33m',
    'Cyan': '\033[96m',
    'Magenta': '\033[95m',
    'DarkGray': '\033[90m',
    'Reset': '\033[0m',
}


@dataclass
class Settings:
    mode: str = 'Memorable'
    length: int = 16
    word_count: int = 5
    uppercase: bool = True
    numbers: bool = True
    symbols: bool = True
    separator: str = 'Hyphens'
    substitutions: bool = False


@dataclass
class Score:
    bits: float
    label: str
    color: str
    crack_time: str


# ---------------------------------------------------------------------------
# Generation logic
# ---------------------------------------------------------------------------

def substitute(text):
    return ''.join(SUBSTITUTION_MAP.get(ch, ch) for ch in text)


def generate_random_password(length, use_uppercase, use_numbers, use_symbols):
    categories = [LOWER_CHARS]
    if use_uppercase:
        categories.append(UPPER_CHARS)
    if use_numbers:
        categories.append(DIGIT_CHARS)
    if use_symbols:
        categories.append(SYMBOL_CHARS)
    pool = ''.join(categories)

    password_chars = [secrets.choice(pool) for _ in range(length)]

    # Guarantee at least one character from each selected category
    for i, category in enumerate(categories):
        if i < len(password_chars):
            password_chars[i] = secrets.choice(category)

    # Shuffle so the guaranteed characters aren't always up front
    for i in range(len(password_chars) - 1, 0, -1):
        j = secrets.randbelow(i + 1)
        password_chars[i], password_chars[j] = password_chars[j], password_chars[i]

    return ''.join(password_chars)


def generate_memorable_password(word_count, capitalize, use_numbers, use_substitutions, separator):
    parts = []
    for _ in range(word_count):
        word = secrets.choice(WORD_LIST)
        if capitalize:
            word = word[0].upper() + word[1:]
        if use_substitutions:
            word = substitute(word)
        if use_numbers:
            word = f'{word}{secrets.randbelow(9)}'
        parts.append(word)

    return SEPARATORS.get(separator, '').join(parts)


def generate_password(settings):
    if settings.mode == 'Random':
        return generate_random_password(
            settings.length, settings.uppercase, settings.numbers, settings.symbols
        )
    return generate_memorable_password(
        settings.word_count, settings.uppercase, settings.numbers,
        settings.substitutions, settings.separator
    )


# ---------------------------------------------------------------------------
# Security score / crack-time estimate
# ---------------------------------------------------------------------------

def entropy_bits(settings):
    if settings.mode == 'Random':
        pool_size = len(LOWER_CHARS)
        if settings.uppercase:
            pool_size += len(UPPER_CHARS)
        if settings.numbers:
            pool_size += len(DIGIT_CHARS)
        if settings.symbols:
            pool_size += len(SYMBOL_CHARS)
        return settings.length * math.log2(pool_size)

    bits = settings.word_count * math.log2(len(WORD_LIST))
    if settings.numbers:
        bits += settings.word_count * math.log2(10)
    return bits


def format_timespan_friendly(seconds):
    if seconds < 1:
        return 'instantly'
    if seconds < 60:
        return f'{seconds:,.0f} seconds'
    if seconds < 3600:
        return f'{seconds / 60:,.0f} minutes'
    if seconds < 86400:
        return f'{seconds / 3600:,.0f} hours'
    if seconds < 2592000:
        return f'{seconds / 86400:,.0f} days'
    if seconds < 31536000:
        return f'{seconds / 2592000:,.0f} months'
    if seconds < 31536000000:
        return f'{seconds / 31536000:,.0f} years'
    if seconds < 31536000000000:
        return f'{seconds / 31536000000:,.0f} thousand years'
    return 'thousands of years'


def get_security_score(settings):
    bits = entropy_bits(settings)

    # Rough illustrative model: assume 1e10 guesses/sec (fast offline attack),
    # average-case guesswork is half the keyspace.
    guesses_per_second = 1e10
    seconds = (2 ** (bits - 1)) / guesses_per_second

    label, color = 'Very weak', 'Red'
    if bits >= 80:
        label, color = 'Very strong', 'Cyan'
    elif bits >= 60:
        label, color = 'Strong', 'Green'
    elif bits >= 40:
        label, color = 'Reasonable', 'Yellow'
    elif bits >= 28:
        label, color = 'Weak', 'DarkYellow'

    return Score(bits=round(bits, 1), label=label, color=color,
                 crack_time=format_timespan_friendly(seconds))


# ---------------------------------------------------------------------------
# Interactive menu
# ---------------------------------------------------------------------------

def colorize(text, color):
    return f"{COLORS.get(color, '')}{text}{COLORS['Reset']}"


def on_off(value):
    return 'On' if value else 'Off'


def clear_screen():
    os.system('cls' if os.name == 'nt' else 'clear')


def show_menu(password, alternates, score, settings):
    clear_screen()
    print()
    print(colorize('  PASSWORD GENERATOR', 'Magenta'))
    print(colorize('  Generate strong, unique passwords.', 'DarkGray'))
    print(colorize('  ' + '-' * 60, 'DarkGray'))
    print()
    print(colorize(f'   {password}', 'Cyan'))
    print()
    print(f'  Security score : {score.bits} bits  -  '
          + colorize(score.label, score.color)
          + f'   (~{score.crack_time} to crack)')
    print(colorize('  ' + '-' * 60, 'DarkGray'))
    print(f'  Mode         : {settings.mode}')
    if settings.mode == 'Random':
        print(f'  Length       : {settings.length}')
        print(f'  Uppercase    : {on_off(settings.uppercase)}')
        print(f'  Numbers      : {on_off(settings.numbers)}')
        print(f'  Symbols      : {on_off(settings.symbols)}')
    else:
        print(f'  Word count   : {settings.word_count}')
        print(f'  Capitalize   : {on_off(settings.uppercase)}')
        print(f'  Numbers      : {on_off(settings.numbers)}')
        print(f'  Separator    : {settings.separator}')
        print(f'  Substitutions: {on_off(settings.substitutions)}  (a->@ e->3 i->1 o->0 s->$ t->7 ...)')
    print(colorize('  ' + '-' * 60, 'DarkGray'))
    print(colorize('  More passwords:', 'DarkGray'))
    for alt in alternates:
        print(colorize(f'   {alt}', 'DarkGray'))
    print(colorize('  ' + '-' * 60, 'DarkGray'))
    print(colorize('  [Enter] Regenerate     [Y] Copy to clipboard', 'DarkGray'))
    print(colorize('  [M] Switch mode', 'DarkGray'))
    if settings.mode == 'Random':
        print(colorize('  [L] Length             [U] Toggle uppercase', 'DarkGray'))
        print(colorize('  [N] Toggle numbers     [X] Toggle symbols', 'DarkGray'))
    else:
        print(colorize('  [W] Word count         [U] Toggle capitalize', 'DarkGray'))
        print(colorize('  [N] Toggle numbers     [S] Separator', 'DarkGray'))
        print(colorize('  [K] Toggle substitutions', 'DarkGray'))
    print(colorize('  [Q] Quit', 'DarkGray'))
    print()


def read_length(settings):
    val = input('  Enter length (6-64): ')
    if val.isdigit() and 6 <= int(val) <= 64:
        settings.length = int(val)


def read_word_count(settings):
    val = input('  Enter word count (1-8): ')
    if val.isdigit() and 1 <= int(val) <= 8:
        settings.word_count = int(val)


def read_separator(settings):
    print('  1) Hyphens  2) Underscores  3) Dots  4) Spaces  5) None')
    val = input('  Choose a separator: ')
    mapping = {'1': 'Hyphens', '2': 'Underscores', '3': 'Dots', '4': 'Spaces', '5': 'None'}
    if val in mapping:
        settings.separator = mapping[val]


def get_display_bundle(settings):
    password = generate_password(settings)
    alternates = [generate_password(settings) for _ in range(4)]
    score = get_security_score(settings)
    return password, alternates, score


def copy_to_clipboard(password):
    try:
        import pyperclip
        pyperclip.copy(password)
        print(colorize(f"  Copied '{password}' to clipboard.", 'Green'))
    except Exception:
        print(colorize('  Clipboard not available on this system.', 'Yellow'))
    time.sleep(0.9)


def interactive(settings):
    password, alternates, score = get_display_bundle(settings)

    while True:
        show_menu(password, alternates, score, settings)
        choice = input('  Choice: ').strip().upper()

        if choice == '':
            password, alternates, score = get_display_bundle(settings)
        elif choice == 'M':
            settings.mode = 'Random' if settings.mode == 'Memorable' else 'Memorable'
            password, alternates, score = get_display_bundle(settings)
        elif choice == 'L' and settings.mode == 'Random':
            read_length(settings)
            password, alternates, score = get_display_bundle(settings)
        elif choice == 'W' and settings.mode == 'Memorable':
            read_word_count(settings)
            password, alternates, score = get_display_bundle(settings)
        elif choice == 'S' and settings.mode == 'Memorable':
            read_separator(settings)
            password, alternates, score = get_display_bundle(settings)
        elif choice == 'U':
            settings.uppercase = not settings.uppercase
            password, alternates, score = get_display_bundle(settings)
        elif choice == 'N':
            settings.numbers = not settings.numbers
            password, alternates, score = get_display_bundle(settings)
        elif choice == 'X' and settings.mode == 'Random':
            settings.symbols = not settings.symbols
            password, alternates, score = get_display_bundle(settings)
        elif choice == 'K' and settings.mode == 'Memorable':
            settings.substitutions = not settings.substitutions
            password, alternates, score = get_display_bundle(settings)
        elif choice == 'Y':
            copy_to_clipboard(password)
        elif choice == 'Q':
            print()
            return


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def ranged_int(lo, hi):
    def parse(value):
        try:
            ivalue = int(value)
        except ValueError:
            raise argparse.ArgumentTypeError(f'{value!r} is not an integer')
        if not lo <= ivalue <= hi:
            raise argparse.ArgumentTypeError(f'must be between {lo} and {hi}')
        return ivalue
    return parse


def parse_args():
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument('--mode', choices=['Random', 'Memorable'], default='Memorable')
    parser.add_argument('--length', type=ranged_int(6, 64), default=16,
                         help='Random mode: total character length (6-64). Default: 16.')
    parser.add_argument('--word-count', type=ranged_int(1, 8), default=5,
                         help='Memorable mode: how many words to combine (1-8). Default: 5.')
    parser.add_argument('--uppercase', action=argparse.BooleanOptionalAction, default=True,
                         help='Random mode: include uppercase letters. Memorable mode: capitalize each word.')
    parser.add_argument('--numbers', action=argparse.BooleanOptionalAction, default=True,
                         help='Include digits.')
    parser.add_argument('--symbols', action=argparse.BooleanOptionalAction, default=True,
                         help='Random mode only: include symbol characters.')
    parser.add_argument('--separator', choices=['Hyphens', 'Underscores', 'Dots', 'Spaces', 'None'],
                         default='Hyphens', help='Memorable mode only.')
    parser.add_argument('--substitutions', action='store_true',
                         help='Memorable mode only: apply leetspeak-style character substitutions.')
    parser.add_argument('--count', type=int, default=1,
                         help='How many passwords to print in one-shot (non-interactive) mode.')
    parser.add_argument('--non-interactive', action='store_true',
                         help='Skip the menu and just print the result(s) and exit.')
    return parser.parse_args()


def main():
    args = parse_args()
    settings = Settings(
        mode=args.mode,
        length=args.length,
        word_count=args.word_count,
        uppercase=args.uppercase,
        numbers=args.numbers,
        symbols=args.symbols,
        separator=args.separator,
        substitutions=args.substitutions,
    )

    if args.non_interactive:
        for _ in range(max(1, args.count)):
            print(generate_password(settings))
        return

    interactive(settings)


if __name__ == '__main__':
    main()
