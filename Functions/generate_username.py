#!/usr/bin/env python3
"""Username Generator - an interactive command-line tool for generating
randomized, secure usernames.

Combines random adjectives / nouns / verbs / first names into a username,
with adjustable word count, separator style, numbers, capitalization,
and leetspeak. Also includes a Military mode that generates
operation-style names (e.g. "Operation Silent Thunder"). Run it
interactively for a live menu, or pass parameters for a single
one-shot result (handy for scripting/piping).

Examples:
  python generate_username.py
      Launches the interactive menu.

  python generate_username.py --non-interactive --word-count 3 --separator Underscores --numbers --count 5
      Prints 5 usernames like "clever_falcon_races42" and exits.

  python generate_username.py --non-interactive --mode Military --word-count 2 --count 5
      Prints 5 operation names like "Operation Crimson Falcon" and exits.
"""

import argparse
import os
import secrets
import time
from dataclasses import dataclass, field

# ---------------------------------------------------------------------------
# Word lists
# ---------------------------------------------------------------------------

ADJECTIVES = (
    'brave','calm','clever','cosmic','crimson','curious','dapper','daring','dizzy','eager',
    'electric','fierce','fluffy','frosty','gentle','golden','happy','hidden','icy','jolly',
    'jumpy','lively','lucky','mighty','misty','mystic','nimble','plucky','quiet','quirky',
    'rapid','rusty','sharp','shiny','silent','silly','sleepy','sly','smoky','snappy',
    'sneaky','solar','sparky','spry','stellar','stormy','sunny','swift','tidy','witty',
    'wild','zesty','breezy','chill','cozy','epic','feral','grumpy','honest','jazzy',
    'ancient','arctic','azure','bionic','blazing','bold','bouncy','bubbly','bumpy','burly',
    'candid','carefree','cheeky','chirpy','chunky','classy','cloudy','coastal','coral','crafty',
    'creaky','crisp','crooked','crunchy','crystal','cuddly','dashing','dawning','deep','defiant',
    'devout','dreamy','drowsy','dusty','earthy','elegant','emerald','enchanted','endless','evasive',
    'expert','faded','faint','famous','fearless','fizzy','flashy','fleeting','flickering','floral',
    'foamy','foggy','forgotten','fragrant','frantic','frozen','fuzzy','gallant','gigantic','glassy',
    'gleaming','glimmering','glossy','graceful','grand','gritty','groovy','hardy','harmless','hasty',
    'hazy','heroic','holographic','hollow','humble','hushed','hyper','idle','impish','indigo',
    'infinite','inky','ivory','jagged','jaunty','jubilant','keen','knightly','knobby','lanky',
    'legendary','lofty','lonely','loud','loyal','lush','magnetic','majestic','marbled','massive',
    'melodic','mellow','merry','metallic','midnight','minty','modest','moonlit','muddy','murky',
    'musical','narrow','neat','nifty','noble','nocturnal','nostalgic','oaken','obsidian','odd',
    'olive','opal','orbital','ornate','outlandish','pastel','peaceful','peppy','perky','petite',
    'pixelated','placid','playful','plump','polar','polished','posh','prickly','proud','punchy',
    'radiant','ragged','rambling','rare','regal','restless','ripe','robust','rogue','rowdy',
    'royal','rugged','rumbling','sable','salty','sandy','savage','scarlet','scrappy','scruffy',
    'serene','shadowy','shaggy','shallow','shimmering','shrewd','sizzling','skittish','slick','slippery',
    'smooth','snug','soaring','soft','sonic','sparkling','speckled','spicy','spirited','splendid',
    'spooky','spotless','springy','squishy','stalwart','steady','steel','stealthy','sturdy','subtle',
    'supreme','swanky','tangled','tenacious','thorny','thrifty','thundering','tidal','timid','tiny',
    'toasty','towering','tranquil','trusty','tumbling','turbo','twilight','twinkling','ultra','unruly',
    'valiant','velvet','vibrant','vintage','vivid','wandering','warm','weathered','whimsical','windy',
    'wispy','wobbly','wondrous','woolly','wry','young','zany','zippy','zonal','zealous',
    'agile','amber','ample','bashful','blithe','bright','brisk','buoyant','cheery','chipper',
    'crafted','dainty','deft','droll','dusky','eerie','feisty','fervent','flinty','frisky',
    'gleeful','gutsy','hale','hearty','hoary','jovial','kindly','lavish','limber','lucid',
    'marshy','mirthful','moody','mossy','nippy','nutty','pearly','pensive','plush','poised',
    'rosy','rustic','sassy','scenic','sedate','snowy','spiffy','spunky','starry','steamy',
    'stout','swell','tawny','timeless','upbeat','wary','wavy','wintry',
)

NOUNS = (
    'badger','beacon','cobra','comet','condor','coyote','crane','dolphin','dragon','eagle',
    'ember','falcon','ferret','fox','glacier','gopher','griffin','harbor','hawk','heron',
    'jaguar','kestrel','kite','koala','lantern','lemur','lynx','magpie','maple','meteor',
    'moose','nebula','ocelot','orchid','otter','panther','panda','phoenix','pixel','planet',
    'puma','quokka','raven','reef','rocket','shadow','sparrow','tiger','viper','willow',
    'wolf','wombat','zephyr','canyon','cascade','citadel','forge','summit','anchor','antler',
    'arbor','archer','arrow','asteroid','atlas','aurora','avalanche','banner','baron','basin',
    'blizzard','bluff','bonfire','boulder','breeze','bridge','brook','cabin','cactus','cairn',
    'campfire','canvas','canopy','castle','cavern','cedar','chalice','chariot','cinder','cipher',
    'circuit','citrus','cliff','clover','cobalt','compass','continent','coral','cottage','crater',
    'creek','crescent','crown','crystal','current','cypress','delta','desert','diamond','dune',
    'dusk','dynamo','eclipse','engine','envoy','equinox','estuary','fable','falls','fern',
    'firefly','fjord','flame','flare','flint','fossil','fountain','frontier','galaxy','garnet',
    'geyser','glade','glider','glimmer','globe','granite','gravel','grove','gully','gyro',
    'halo','hammer','harvest','haven','hemlock','hollow','horizon','hurricane','hydra','iceberg',
    'igloo','inferno','island','ivy','jasper','jetstream','jungle','jupiter','keystone','kingdom',
    'labyrinth','lagoon','landmark','laser','ledge','legion','ley','lightning','lodge','longbow',
    'lumen','lunar','magnet','mammoth','mantle','marble','marsh','matrix','mesa','meridian',
    'mirage','mirror','mist','monolith','monsoon','moonbeam','mosaic','mosswood','mountain','nectar',
    'needle','nova','nucleus','oasis','obelisk','onyx','opal','orbit','origin','outpost',
    'overlook','oxide','pagoda','palisade','pathway','peak','pebble','pendant','pinnacle','pioneer',
    'plateau','portal','prairie','prism','prowler','pulsar','quarry','quartz','quest','quiver',
    'radar','rampart','rapids','ravine','realm','reservoir','rhythm','ridge','rift','ripple',
    'riverbank','rune','sable','saga','sanctuary','satellite','savanna','scepter','schooner','scout',
    'sentinel','sequoia','shard','shore','shrine','signal','silo','skiff','skyline','slate',
    'sleigh','solstice','spectrum','sphinx','spire','spore','spruce','stallion','starfall','statue',
    'steppe','strait','stronghold','sundial','surge','swamp','tempest','terrace','thicket','thistle',
    'thunder','tidepool','timber','torch','totem','trailblazer','trek','trench','trestle','trident',
    'tundra','turret','tusk','twister','undertow','vagabond','valley','vanguard','vantage','vapor',
    'vault','velocity','vertex','vessel','vineyard','vista','volcano','vortex','voyage','warden',
    'waterfall','wavelength','wharf','whirlpool','wildfire','wilderness','windmill','wingman','wisp','wizard',
    'wraith','wreck','yeti','zenith','zodiac','abacus','acorn','alcove','amulet','anvil',
    'armada','attic','bayou','bison','blossom','bobcat','burrow','caldera','caravan','carousel',
    'catamaran','cheetah','clipper','cockpit','cougar','cumulus','dingo','egret','elk','flagship',
    'flotilla','galleon','gondola','gorge','gryphon','hamlet','hearth','heath','hornet','husky',
    'ibis','jackal','kayak','kelp','lighthouse','llama','locket','lookout','meadow','mariner',
    'marten','mongoose','moor','narwhal','osprey','pelican','penguin','quail','raccoon','reindeer',
    'scarab','skylark','sprocket','starling','stork','toucan','walrus','warbler',
)

VERBS = (
    'blazes','bolts','chases','climbs','dances','darts','dashes','dives','drifts','drives',
    'explores','flies','floats','glides','gallops','glows','hops','hunts','jumps','leaps',
    'lurks','prowls','races','roams','roars','rolls','runs','sails','sneaks','soars',
    'sparks','spins','sprints','stalks','surges','swims','swoops','trots','wanders','zooms',
    'builds','carves','charges','crafts','dreams','flows','forges','ignites','shines','ascends',
    'awakens','balances','bends','bounces','breaks','bristles','bursts','calculates','captures','careens',
    'catapults','circles','clashes','coasts','collides','conjures','conquers','creeps','crosses','crumbles',
    'cruises','crushes','defends','defies','delivers','descends','detects','devours','discovers','dodges',
    'doubles','draws','drums','echoes','emerges','endures','erupts','escapes','evolves','expands',
    'fades','falls','fights','flares','flashes','flickers','flips','flutters','forages','gathers',
    'generates','glimmers','glistens','governs','grabs','grinds','grips','grows','guards','guides',
    'hammers','harnesses','haunts','hides','hikes','holds','howls','hovers','hums','hurls',
    'inspires','invents','journeys','juggles','kindles','launches','leads','leaks','learns','levitates',
    'lifts','lights','lingers','locks','looms','lunges','maneuvers','marches','masters','meanders',
    'merges','migrates','mines','moves','multiplies','navigates','nests','oscillates','outruns','paddles',
    'patrols','pierces','pilots','plants','plots','plunges','ponders','pounces','powers','presses',
    'probes','projects','propels','protects','pulses','pursues','quakes','radiates','rallies','reaches',
    'rebounds','reflects','releases','resonates','rests','reveals','rides','rises','rockets','rumbles',
    'scales','scans','scatters','scours','searches','seeks','shapes','shatters','shields','shifts',
    'shovels','signals','simmers','sings','skates','sketches','skips','skirts','slides','slinks',
    'slithers','smolders','snaps','snoops','solves','spans','sprouts','stampedes','steers','stirs',
    'stomps','streaks','strides','strikes','strolls','summons','surfs','surveys','sweeps','swerves',
    'swirls','tackles','tames','tangles','targets','thrives','thrusts','tilts','tinkers','towers',
    'traces','tracks','trails','transforms','traverses','treks','trembles','triggers','triumphs','trudges',
    'tumbles','tunnels','twirls','unfolds','unleashes','unlocks','unwinds','vaults','ventures','vibrates',
    'voyages','wades','wakes','watches','weaves','whirls','whistles','wields','winds','wraps',
    'babbles','basks','beams','blooms','bobs','booms','brews','bumbles','canters','chimes',
    'chirps','clatters','coils','crackles','croons','dawdles','deflects','dips','ebbs','fetches',
    'fizzes','fumbles','gleams','glints','grazes','greets','gusts','hoists','jingles','jogs',
    'lopes','mends','mingles','muses','orbits','paces','peeks','perches','pivots','plays',
    'purrs','rambles','rattles','roves','rustles','saunters','scurries','skims','sways','tiptoes',
    'trills','waddles','wiggles','yodels','zigzags',
)

NAMES = (
    'James','John','Robert','Michael','William','David','Richard','Joseph','Thomas','Charles',
    'Christopher','Daniel','Matthew','Anthony','Mark','Donald','Steven','Paul','Andrew','Joshua',
    'Kenneth','Kevin','Brian','George','Edward','Ronald','Timothy','Jason','Jeffrey','Ryan',
    'Jacob','Gary','Nicholas','Eric','Jonathan','Stephen','Larry','Justin','Scott','Brandon',
    'Benjamin','Samuel','Gregory','Alexander','Patrick','Frank','Raymond','Jack','Dennis','Jerry',
    'Tyler','Aaron','Jose','Adam','Nathan','Henry','Douglas','Zachary','Peter','Kyle',
    'Walter','Ethan','Jeremy','Harold','Keith','Christian','Roger','Noah','Gerald','Carl',
    'Terry','Sean','Austin','Arthur','Lawrence','Jesse','Dylan','Bryan','Joe','Billy',
    'Bruce','Albert','Willie','Gabriel','Logan','Alan','Juan','Wayne','Roy','Ralph',
    'Randy','Eugene','Vincent','Russell','Elijah','Louis','Bobby','Philip','Johnny','Mason',
    'Mary','Patricia','Jennifer','Linda','Elizabeth','Barbara','Susan','Jessica','Sarah','Karen',
    'Nancy','Lisa','Margaret','Betty','Sandra','Ashley','Dorothy','Kimberly','Emily','Donna',
    'Michelle','Carol','Amanda','Melissa','Deborah','Stephanie','Rebecca','Sharon','Laura','Cynthia',
    'Kathleen','Amy','Angela','Shirley','Anna','Brenda','Pamela','Emma','Nicole','Helen',
    'Samantha','Katherine','Christine','Debra','Rachel','Carolyn','Janet','Maria','Heather','Diane',
    'Julie','Joyce','Victoria','Kelly','Christina','Lauren','Joan','Evelyn','Olivia','Judith',
    'Megan','Cheryl','Martha','Andrea','Frances','Hannah','Jacqueline','Ann','Gloria','Jean',
    'Kathryn','Alice','Teresa','Sara','Janice','Doris','Madison','Julia','Grace','Judy',
    'Abigail','Marie','Denise','Beverly','Amber','Theresa','Marilyn','Danielle','Diana','Brittany',
    'Natalie','Sophia','Rose','Isabella','Alexis','Kayla','Charlotte','Taylor','Morgan','Casey',
    'Riley','Avery','Peyton','Quinn','Skyler','Cameron','Reese','Rowan','Sage','Dakota',
    'Emerson','Finley','Harper','Hayden','Jamie','Kendall','Marley','Parker','Phoenix','River',
    'Robin','Shawn','Sydney','Blair','Charlie','Addison','Aiden','Alex','Ari','Aubrey',
    'Bailey','Blake','Brooke','Carter','Chloe','Cole','Dana','Devon','Drew','Eden',
    'Eli','Ellis','Elliot','Ezra','Hazel','Hunter','Ivy','Jade','Jules','Kai',
    'Lane','Leah','Leo','Lila','Lucas','Luna','Micah','Mila','Nora','Owen',
    'Paige','Quincy','Remy','Sawyer','Scout','Sienna','Theo','Wren','Zoe','Zion',
)

MILITARY_WORDS_A = (
    'silent','iron','crimson','desert','enduring','relentless','vigilant','rapid','final','golden',
    'swift','savage','fierce','brave','bold','hidden','phantom','rogue','lethal','tactical',
    'covert','resolute','valiant','fearless','ruthless','decisive','forward','unseen','ghost','black',
    'white','scarlet','azure','obsidian','arctic','broken','unbroken','sudden','grim','cold',
    'dark','deep','high','last','lone','wild','steady','sharp','hard','true',
    'free','righteous','sovereign','unified','allied','combined','joint','distant','forgotten','buried',
    'ancient','eternal','sacred','absolute','total','clean','quiet','still','shadow','midnight',
    'northern','southern','eastern','western','falling','rising','burning','frozen','stormy','silver',
    'steel','granite','hollow','endless','infinite','urgent','critical','primary','prime','ultimate',
    'supreme','superior','dominant','imperial','royal','noble','glorious','triumphant','victorious','unstoppable',
    'unbreakable','unyielding','undaunted','dauntless','gallant','heroic','legendary','mythic','epic','titanic',
    'colossal','mighty','powerful','aggressive','defensive','armored','fortified','reinforced','hardened','tempered',
    'forged','molten','blazing','scorching','freezing','icy','frosty','misty','foggy','hazy',
    'radiant','luminous','gleaming','polished','sleek','precise','calculated','methodical','strategic','watchful',
    'alert','keen','nocturnal','timeless','immortal','deadly','perilous','treacherous','volatile','explosive',
    'toxic','venomous','corrosive','jagged','serrated','barbed','thorny','bristling','armed','militant',
    'disciplined','seasoned','veteran','elite','classified','encrypted','masked','camouflaged','invisible','untraceable',
    'nameless','faceless','wordless','cunning','shrewd','masterful','expert','efficient','effective','tireless',
    'unwavering','steadfast','loyal','devoted','determined','driven','ambitious','patrolling','storming','liberating',
    'sealed','locked','exposed','vulnerable','layered','intricate','essential','vital','crucial','pivotal',
    'amber','ashen','blind','bloodless','bronze','burnished','charging','cobalt','crashing','crescent',
    'daring','deliberate','echoing','emerald','errant','fading','fallen','flanking','gathering','guarded',
    'hunting','ironclad','jade','lasting','lightning','marching','nightfall','onward','piercing','prowling',
    'rolling','scarred','shattered','sleepless','sweeping','thundering','tidal','vengeful','wandering','winter',
)

MILITARY_WORDS_B = (
    'thunder','storm','hammer','fury','justice','freedom','guardian','sentinel','phantom','valor',
    'havoc','viper','falcon','eagle','wolf','cobra','scorpion','dragon','reaper','specter',
    'vanguard','resolve','endeavor','shield','spear','blade','saber','lance','arrow','talon',
    'claw','fang','hurricane','cyclone','tempest','blizzard','avalanche','wildfire','inferno','phoenix',
    'condor','hawk','raptor','python','mongoose','jackal','panther','lion','tiger','bear',
    'shark','trident','anchor','harpoon','rampart','bastion','citadel','fortress','bulwark','garrison',
    'legion','watchtower','beacon','torch','ember','frost','summit','ridge','horizon','dawn',
    'dusk','twilight','eclipse','comet','meteor','crossbow','musket','warhammer','ironclad','barracuda',
    'grizzly','cougar','lynx','boar','ram','stallion','mustang','bronco','wolverine','badger',
    'hornet','wasp','rattlesnake','mamba','adder','kraken','leviathan','behemoth','colossus','titan',
    'juggernaut','tsunami','maelstrom','vortex','whirlwind','gale','monsoon','typhoon','squall','thunderbolt',
    'lightning','rearguard','sentry','watchman','outpost','stronghold','redoubt','blockhouse','trench','bunker',
    'silo','arsenal','armory','cache','depot','convoy','brigade','battalion','regiment','squadron',
    'platoon','division','corps','cavalry','infantry','artillery','ordnance','munitions','warhead','payload',
    'salvo','barrage','volley','broadside','cannon','mortar','howitzer','bayonet','dagger','cutlass',
    'rapier','halberd','javelin','catapult','ballista','trebuchet','gauntlet','aegis','palisade','barricade',
    'blockade','cordon','perimeter','frontier','borderland','wasteland','badlands','highland','tundra','steppe',
    'canyon','gorge','ravine','chasm','abyss','crater','volcano','glacier','iceberg','wildland',
    'marsh','swamp','delta','estuary','harbor','cove','inlet','strait','channel','undertow',
    'riptide','breaker','cascade','waterfall','geyser','oasis','mirage','dune','mesa','plateau',
    'albatross','anvil','bastille','bearcat','bladefall','buckler','caliber','chimera','claymore','crusader',
    'dreadnought','falchion','flail','gladiator','gorgon','hydra','jaguar','katana','kestrel','longbow',
    'manticore','minotaur','osprey','paladin','pike','ranger','scimitar','siegebreaker','slingshot','spartan',
    'stingray','tomahawk','warbird','warden','warlord','broadsword','firebrand','ironside','starfire','warpath',
)

# ---------------------------------------------------------------------------
# Generation logic
# ---------------------------------------------------------------------------

LEET_MAP = {
    'a': '4', 'e': '3', 'i': '1', 'o': '0', 's': '5', 't': '7', 'g': '9', 'b': '8',
}

SEPARATORS = {
    'Hyphens': '-',
    'Underscores': '_',
    'Dots': '.',
    'Spaces': ' ',
    'None': '',
}


def leetspeak(text):
    return ''.join(LEET_MAP.get(ch.lower(), ch) for ch in text)


def generate_username(word_count, separator, use_numbers, capitalize, use_leetspeak,
                       use_adjectives, use_nouns, use_verbs, use_names):
    pools = []
    if use_adjectives:
        pools.append(ADJECTIVES)
    if use_nouns:
        pools.append(NOUNS)
    if use_verbs:
        pools.append(VERBS)
    if use_names:
        pools.append(NAMES)
    if not pools:
        # Fall back so the generator never produces an empty string
        pools = [NOUNS]

    words = []
    for i in range(word_count):
        pool = pools[i % len(pools)]
        word = secrets.choice(pool).lower()
        if use_leetspeak:
            word = leetspeak(word)
        if capitalize and word:
            word = word[0].upper() + word[1:]
        words.append(word)

    sep = SEPARATORS.get(separator, '')
    result = sep.join(words)

    if use_numbers:
        number = secrets.randbelow(100)
        result = f'{result}{number}' if sep == '' else f'{result}{sep}{number}'

    return result


def generate_military_op_name(word_count, separator, use_leetspeak, use_numbers):
    pools = (MILITARY_WORDS_A, MILITARY_WORDS_B)

    words = []
    for i in range(word_count):
        pool = pools[i % len(pools)]
        word = secrets.choice(pool).lower()
        if use_leetspeak:
            word = leetspeak(word)
        word = word[0].upper() + word[1:]
        words.append(word)

    sep = SEPARATORS.get(separator, '')
    body = sep.join(words)

    if use_numbers:
        number = secrets.randbelow(100)
        body = f'{body}{number}' if sep == '' else f'{body}{sep}{number}'

    return f'Operation {body}'


def get_current_username(settings):
    if settings.mode == 'Military':
        # Operation names are always title-cased, regardless of the Capitalize toggle
        return generate_military_op_name(
            settings.word_count, settings.separator, settings.leetspeak, settings.numbers
        )

    return generate_username(
        settings.word_count, settings.separator, settings.numbers, settings.capitalize, settings.leetspeak,
        'Adjectives' in settings.word_types, 'Nouns' in settings.word_types,
        'Verbs' in settings.word_types, 'Names' in settings.word_types,
    )


@dataclass
class Settings:
    mode: str = 'Standard'
    word_count: int = 2
    separator: str = 'Hyphens'
    numbers: bool = False
    capitalize: bool = False
    leetspeak: bool = False
    word_types: list = field(default_factory=lambda: ['Adjectives', 'Nouns', 'Verbs'])


# ---------------------------------------------------------------------------
# Interactive menu
# ---------------------------------------------------------------------------

COLORS = {
    'Magenta': '\033[95m',
    'Cyan': '\033[96m',
    'DarkGray': '\033[90m',
    'Yellow': '\033[93m',
    'Green': '\033[92m',
    'Reset': '\033[0m',
}


def colorize(text, color):
    return f"{COLORS.get(color, '')}{text}{COLORS['Reset']}"


def on_off(value):
    return 'On' if value else 'Off'


def clear_screen():
    os.system('cls' if os.name == 'nt' else 'clear')


def show_menu(current, settings):
    clear_screen()
    print()
    print(colorize('  USERNAME GENERATOR', 'Magenta'))
    print(colorize('  Stay safe online with randomized, secure usernames.', 'DarkGray'))
    print(colorize('  ' + '-' * 56, 'DarkGray'))
    print()
    print(colorize(f'   {current}', 'Cyan'))
    print()
    print(colorize('  ' + '-' * 56, 'DarkGray'))
    print(f'  Mode         : {settings.mode}')
    print(f'  Word count   : {settings.word_count}')
    print(f'  Separator    : {settings.separator}')
    print(f'  Numbers      : {on_off(settings.numbers)}')
    print(f'  Capitalize   : {on_off(settings.capitalize)}')
    print(f'  Leetspeak    : {on_off(settings.leetspeak)}')
    if settings.mode == 'Standard':
        print(f"  Word types   : {', '.join(settings.word_types)}")
    print(colorize('  ' + '-' * 56, 'DarkGray'))
    print(colorize('  [Enter] Regenerate   [Y] Copy to clipboard', 'DarkGray'))
    print(colorize('  [M] Toggle mode (Standard / Military)', 'DarkGray'))
    print(colorize('  [W] Word count       [S] Separator', 'DarkGray'))
    print(colorize('  [N] Toggle numbers   [C] Toggle capitalize', 'DarkGray'))
    if settings.mode == 'Standard':
        print(colorize('  [L] Toggle leetspeak [T] Toggle word types', 'DarkGray'))
    else:
        print(colorize('  [L] Toggle leetspeak', 'DarkGray'))
    print(colorize('  [Q] Quit', 'DarkGray'))
    print()


def read_word_count(settings):
    val = input('  Enter word count (1-5): ')
    if val.isdigit() and 1 <= int(val) <= 5:
        settings.word_count = int(val)


def read_separator(settings):
    print('  1) Hyphens  2) Underscores  3) Dots  4) Spaces  5) None')
    val = input('  Choose a separator: ')
    mapping = {'1': 'Hyphens', '2': 'Underscores', '3': 'Dots', '4': 'Spaces', '5': 'None'}
    if val in mapping:
        settings.separator = mapping[val]


def read_word_types(settings):
    print(f"  Toggle which pools to use (current: {', '.join(settings.word_types)})")
    print('  1) Adjectives  2) Nouns  3) Verbs  4) Names  0) Done')
    mapping = {'1': 'Adjectives', '2': 'Nouns', '3': 'Verbs', '4': 'Names'}
    while True:
        val = input('  Toggle (0 to finish): ')
        if val == '0':
            break
        word_type = mapping.get(val)
        if word_type:
            if word_type in settings.word_types:
                if len(settings.word_types) > 1:
                    settings.word_types.remove(word_type)
                else:
                    print(colorize('  At least one word type must stay selected.', 'Yellow'))
            else:
                settings.word_types.append(word_type)


def copy_to_clipboard(username):
    try:
        import pyperclip
        pyperclip.copy(username)
        print(colorize(f"  Copied '{username}' to clipboard.", 'Green'))
    except Exception:
        print(colorize('  Clipboard not available on this system.', 'Yellow'))
    time.sleep(0.9)


def interactive(settings):
    current = get_current_username(settings)

    while True:
        show_menu(current, settings)
        choice = input('  Choice: ').strip().upper()

        if choice == '':
            current = get_current_username(settings)
        elif choice == 'M':
            settings.mode = 'Military' if settings.mode == 'Standard' else 'Standard'
            if settings.mode == 'Military' and settings.separator == 'Hyphens':
                settings.separator = 'Spaces'
            current = get_current_username(settings)
        elif choice == 'W':
            read_word_count(settings)
            current = get_current_username(settings)
        elif choice == 'S':
            read_separator(settings)
            current = get_current_username(settings)
        elif choice == 'N':
            settings.numbers = not settings.numbers
            current = get_current_username(settings)
        elif choice == 'C':
            settings.capitalize = not settings.capitalize
            current = get_current_username(settings)
        elif choice == 'L':
            settings.leetspeak = not settings.leetspeak
            current = get_current_username(settings)
        elif choice == 'T' and settings.mode == 'Standard':
            read_word_types(settings)
            current = get_current_username(settings)
        elif choice == 'Y':
            copy_to_clipboard(current)
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
    parser.add_argument('--mode', choices=['Standard', 'Military'], default='Standard')
    parser.add_argument('--word-count', type=ranged_int(1, 5), default=2,
                         help='How many words to combine (1-5). Default: 2.')
    parser.add_argument('--separator', choices=['Hyphens', 'Underscores', 'Dots', 'Spaces', 'None'],
                         default='Hyphens')
    parser.add_argument('--numbers', action='store_true', help='Append a random 1-2 digit number.')
    parser.add_argument('--capitalize', action='store_true',
                         help='Capitalize the first letter of each word.')
    parser.add_argument('--leetspeak', action='store_true',
                         help='Replace letters with lookalike numbers (a->4, e->3, i->1, etc).')
    parser.add_argument('--word-types', nargs='+', choices=['Adjectives', 'Nouns', 'Verbs', 'Names'],
                         default=['Adjectives', 'Nouns', 'Verbs'],
                         help='Standard mode only. Which pools to draw from.')
    parser.add_argument('--count', type=int, default=1,
                         help='How many usernames to print in one-shot (non-interactive) mode.')
    parser.add_argument('--non-interactive', action='store_true',
                         help='Skip the menu and just print the result(s) and exit.')
    return parser.parse_args()


def main():
    args = parse_args()
    settings = Settings(
        mode=args.mode,
        word_count=args.word_count,
        separator=args.separator,
        numbers=args.numbers,
        capitalize=args.capitalize,
        leetspeak=args.leetspeak,
        word_types=list(args.word_types),
    )

    if args.non_interactive:
        for _ in range(max(1, args.count)):
            print(get_current_username(settings))
        return

    interactive(settings)


if __name__ == '__main__':
    main()
