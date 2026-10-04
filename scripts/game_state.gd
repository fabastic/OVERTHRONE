extends Node
## Persistent run state: the boss's grimoire, the hero's memory of every skill,
## Dread (per-hero gacha currency), Ascension perks (per hero), Crowns + Eternity
## (permanent prestige upgrades), and the ladder of ever-tougher heroes.
##
## LEARNING MODEL: the hero learns per FIGHT and within a fight. Every skill he is exposed to
## during an attempt gains one "fight" of experience when he dies. Mastery follows an
## exponential curve over fights and is MASTERED after 3 (more with Unknowable). Within a fight
## every hit teaches him a lot (up to +25%), and he reads your habits: parry too much and he
## feints, lean too much and his blade tracks you.
##
## TICKS: all combat runs on a fixed 0.25s tick. Inputs are queued and resolve on the next tick,
## so mashing does nothing. Skill cooldowns, his windups and your parry window are counted in ticks.

signal mastery_milestone(skill_id: String, tier: int)

const PULL_COST := 40
const MAX_RANK := 5
const MAX_LEVEL: int = 6  # Heroes in a run (capped by the HEROES ladder below)
# Stars: how many of his deaths you caused before he conquered you. One star is required to pass him.
const STAR_DEATHS := [5, 8, 11]
const CHECKPOINT_EVERY := 3
const BASE_LOADOUT := 4
const MASTERY_CAP := 0.95
const CURVE_K := 0.9
const BASE_FIGHTS := 3.0
const TICK := 0.25          # one combat tick, in seconds
const GCD_TICKS := 2        # after any cast, nothing else for 2 ticks
const DAYS := 7             # six days with a night of the board each, then the last night
const TIER_NAMES := ["UNKNOWN", "STUDYING", "ADAPTED", "MASTERED"]
const RARITY_NAMES := ["COMMON", "RARE", "LEGENDARY"]
const SCHOOLS := ["HELLFIRE", "BONE", "RIME", "STORM", "VOID", "BLOOD", "WARLORD"]
const SCHOOL_CLASS := {"HELLFIRE": "pyro", "BONE": "bone", "RIME": "rime", "STORM": "storm", "VOID": "void", "BLOOD": "blood", "WARLORD": "war"}

var RARITY_COLORS := [Color(0.75, 0.75, 0.8), Color(0.72, 0.45, 1.0), Color(1.0, 0.78, 0.28)]
var TIER_COLORS := [Color(0.55, 0.55, 0.6), Color(0.95, 0.85, 0.4), Color(1.0, 0.55, 0.2), Color(1.0, 0.2, 0.2)]

# rarity 0 = common (starters live here too, so duplicates can "reforge" them).
var SKILLS := {
	# HELLFIRE
	"fireball": {"name": "Hellfire Orb", "school": "HELLFIRE", "rarity": 0, "color": Color(1.0, 0.45, 0.1), "cooldown": 1.0, "damage": 13.0,
		"counter": "SIDESTEP", "desc": "Hurl a burning orb where you aim."},
	"volley": {"name": "Soul Volley", "school": "HELLFIRE", "rarity": 0, "color": Color(1.0, 0.6, 0.2), "cooldown": 2.2, "damage": 10.0,
		"counter": "SIDESTEP", "desc": "Three burning orbs in a fan. Hard to step around all of them."},
	"pillar": {"name": "Hellfire Pillar", "school": "HELLFIRE", "rarity": 0, "color": Color(1.0, 0.35, 0.1), "cooldown": 2.6, "damage": 30.0,
		"counter": "ROLL", "desc": "A column of fire bursts from the floor where you aim. Fast and narrow."},
	"meteor": {"name": "Falling Star", "school": "HELLFIRE", "rarity": 1, "color": Color(1.0, 0.5, 0.25), "cooldown": 7.0, "damage": 48.0,
		"counter": "SPRINT", "desc": "Call down a burning star. Slow to land, enormous blast."},
	# BONE
	"spikes": {"name": "Bone Spires", "school": "BONE", "rarity": 0, "color": Color(0.95, 0.9, 0.75), "cooldown": 2.2, "damage": 26.0,
		"counter": "ROLL", "desc": "Spires erupt where you aim after a short delay."},
	"slam": {"name": "Throne Quake", "school": "BONE", "rarity": 0, "color": Color(1.0, 0.7, 0.3), "cooldown": 3.5, "damage": 20.0,
		"counter": "LEAP", "desc": "Strike the dais. A shockwave rolls across the hall."},
	"wall": {"name": "Ossuary Wall", "school": "BONE", "rarity": 0, "color": Color(0.85, 0.8, 0.65), "cooldown": 8.0, "damage": 0.0,
		"counter": "VAULT", "desc": "A wall of bones rises across the hall and blocks his advance for a few seconds."},
	"tide": {"name": "Grave Tide", "school": "BONE", "rarity": 1, "color": Color(0.9, 0.75, 0.45), "cooldown": 5.0, "damage": 18.0,
		"counter": "DOUBLE LEAP", "desc": "Two shockwaves, one right behind the other."},
	# RIME
	"lance": {"name": "Rime Lance", "school": "RIME", "rarity": 0, "color": Color(0.45, 0.9, 1.0), "cooldown": 1.4, "damage": 11.0,
		"counter": "PARRY", "desc": "A lance of ice, faster than thought."},
	"bloom": {"name": "Frost Bloom", "school": "RIME", "rarity": 0, "color": Color(0.6, 0.95, 1.0), "cooldown": 4.5, "damage": 6.0,
		"counter": "ROLL", "desc": "Ice flowers burst where you aim, freezing his legs. He moves at half speed."},
	"timerend": {"name": "Time Rend", "school": "RIME", "rarity": 2, "color": Color(0.7, 0.85, 1.0), "cooldown": 14.0, "damage": 0.0,
		"counter": "RESIST", "desc": "Stop his moment in time. He stands frozen for two full seconds."},
	# STORM
	"lightning": {"name": "Sky Lash", "school": "STORM", "rarity": 1, "color": Color(0.7, 0.8, 1.0), "cooldown": 3.0, "damage": 18.0,
		"counter": "WARD", "desc": "Lightning that always finds him. Only a ward can stop it."},
	"doom": {"name": "Doom Mark", "school": "STORM", "rarity": 1, "color": Color(1.0, 0.3, 0.3), "cooldown": 6.0, "damage": 38.0,
		"counter": "DASH", "desc": "A sigil follows him, locks in place, then detonates."},
	"rain": {"name": "Crimson Rain", "school": "STORM", "rarity": 1, "color": Color(0.95, 0.25, 0.3), "cooldown": 6.0, "damage": 12.0,
		"counter": "WEAVE", "desc": "Blood falls around him in a storm of small strikes."},
	# VOID
	"well": {"name": "Gravemaw", "school": "VOID", "rarity": 1, "color": Color(0.65, 0.2, 1.0), "cooldown": 6.0, "damage": 30.0,
		"counter": "ANCHOR", "desc": "A hungry void drags him in, then collapses."},
	"maw": {"name": "Abyssal Rift", "school": "VOID", "rarity": 1, "color": Color(0.5, 0.15, 0.9), "cooldown": 7.0, "damage": 40.0,
		"counter": "STEP OUT", "desc": "The floor splits along a lane down the hall and erupts."},
	"hands": {"name": "Phantom Hands", "school": "VOID", "rarity": 2, "color": Color(0.75, 0.4, 1.0), "cooldown": 9.0, "damage": 55.0,
		"counter": "FALL BACK", "desc": "Your true hands, vast and ghostly, clap down on him from above."},
	"eclipse": {"name": "Eclipse of Self", "school": "VOID", "rarity": 2, "color": Color(1.0, 0.15, 0.25), "cooldown": 12.0, "damage": 0.0,
		"counter": "KINDLE", "desc": "Darkness swallows the hall. He can barely read you, and your attacks deal +40% damage."},
	# BLOOD
	"chains": {"name": "Grasping Chains", "school": "BLOOD", "rarity": 0, "color": Color(0.65, 0.55, 0.85), "cooldown": 4.0, "damage": 6.0,
		"counter": "BREAK AWAY", "desc": "Chains bind him where you aim. A rooted hero is an easy target."},
	"hex": {"name": "Hex of Frailty", "school": "BLOOD", "rarity": 0, "color": Color(0.8, 0.3, 0.6), "cooldown": 10.0, "damage": 0.0,
		"counter": "CLEANSE", "desc": "Curse him. For eight seconds his blade deals half damage."},
	"siphon": {"name": "Blood Siphon", "school": "BLOOD", "rarity": 1, "color": Color(0.9, 0.1, 0.2), "cooldown": 7.0, "damage": 5.0,
		"counter": "BREAK LINE", "desc": "A beam drains him and heals your Will for every drop it takes."},
	"cinder": {"name": "Cinder Nova", "school": "HELLFIRE", "rarity": 1, "color": Color(1.0, 0.4, 0.15), "cooldown": 5.0, "damage": 24.0,
		"counter": "LEAP", "desc": "A ring of fire bursts outward from where you aim."},
	"bonecage": {"name": "Bone Cage", "school": "BONE", "rarity": 1, "color": Color(0.9, 0.85, 0.7), "cooldown": 6.0, "damage": 12.0,
		"counter": "BREAK AWAY", "desc": "Ribs burst from the floor and cage him for two seconds."},
	"glacier": {"name": "Glacier Fan", "school": "RIME", "rarity": 1, "color": Color(0.55, 0.85, 1.0), "cooldown": 3.0, "damage": 10.0,
		"counter": "PARRY", "desc": "Three ice lances in a fan. He has to deflect all of them."},
	"thunder": {"name": "Thunderclap", "school": "STORM", "rarity": 2, "color": Color(0.8, 0.85, 1.0), "cooldown": 8.0, "damage": 20.0,
		"counter": "WARD", "desc": "Sky Lash twice in quick succession. One ward will not be enough."},
	"nullorb": {"name": "Null Orb", "school": "VOID", "rarity": 0, "color": Color(0.55, 0.25, 0.95), "cooldown": 4.0, "damage": 30.0,
		"counter": "SIDESTEP", "desc": "A slow orb of nothing that hunts him across the hall."},
	"leech": {"name": "Leech Swarm", "school": "BLOOD", "rarity": 0, "color": Color(0.8, 0.2, 0.25), "cooldown": 7.0, "damage": 7.0,
		"counter": "CLEAVE", "desc": "Five small leeches skitter at him and burst."},
	"sweep": {"name": "Titan Sweep", "school": "WARLORD", "rarity": 0, "color": Color(0.85, 0.6, 0.45), "cooldown": 4.0, "damage": 26.0,
		"counter": "LEAP", "desc": "Your vast arm sweeps the floor in front of the dais. Only a leap clears it."},
	"grasp": {"name": "Crushing Grasp", "school": "WARLORD", "rarity": 1, "color": Color(0.9, 0.5, 0.4), "cooldown": 7.0, "damage": 36.0,
		"counter": "ROLL", "desc": "Reach out and crush him in your fist. Only works when he is within your reach."},
	"stomp": {"name": "Earthshaker", "school": "WARLORD", "rarity": 0, "color": Color(0.8, 0.55, 0.35), "cooldown": 5.0, "damage": 28.0,
		"counter": "LEAP", "desc": "Stamp down from the dais. A fast, heavy shockwave."},
	"masonry": {"name": "Hurl Masonry", "school": "WARLORD", "rarity": 1, "color": Color(0.75, 0.7, 0.6), "cooldown": 5.5, "damage": 40.0,
		"counter": "SPRINT", "desc": "Tear a block from the wall and throw it where you aim."},
	"ghouls": {"name": "Ghoul Brood", "school": "BLOOD", "rarity": 1, "color": Color(0.6, 0.75, 0.4), "cooldown": 8.0, "damage": 12.0,
		"counter": "CLEAVE", "desc": "Three ghouls crawl from the dais and burst on him."},
}

# The ladder of heroes. Each prestige brings the next one: tougher, with more moves of his own.
var HEROES := [
	{"title": "WREN, THE SQUIRE", "form": 1, "scale": 1.0, "hp": 60.0, "strike": 8.0, "speed": 2.8, "windup": 0.7,
		"armor": Color(0.5, 0.52, 0.56), "cape": Color(0.55, 0.12, 0.1), "moves": ["strike"],
		"lore": "A village boy with a borrowed sword, come to end the tyrant on the throne.\nHe is brave. He is not ready."},
	{"title": "SER CORVIN", "form": 2, "scale": 1.0, "hp": 90.0, "strike": 11.0, "speed": 3.1, "windup": 0.62,
		"armor": Color(0.45, 0.55, 0.75), "cape": Color(0.12, 0.18, 0.5), "moves": ["strike", "lunge"],
		"lore": "A disgraced knight. They say he abandoned a bridge, and his king.\nHe LUNGES from a distance."},
	{"title": "THE LION OF SUNFIELD", "form": 3, "scale": 1.05, "hp": 130.0, "strike": 15.0, "speed": 3.4, "windup": 0.55,
		"armor": Color(0.9, 0.85, 0.65), "cape": Color(0.92, 0.92, 0.95), "moves": ["strike", "lunge", "bolt"],
		"lore": "An arena champion who has never lost. The crowd chants for him even here.\nHe hurls HOLY BOLTS at your face."},
	{"title": "BROTHER ASHE", "form": 2, "scale": 1.1, "hp": 185.0, "strike": 20.0, "speed": 3.7, "windup": 0.5,
		"armor": Color(0.85, 0.88, 0.95), "cape": Color(0.85, 0.65, 0.2), "moves": ["strike", "lunge", "bolt", "leap"],
		"lore": "A paladin of the Cathedral. He has burned a hundred heretics. You are the hundred and first.\nHe LEAPS onto your dais in judgment."},
	{"title": "SAINT ALDER", "form": 3, "scale": 1.12, "hp": 255.0, "strike": 26.0, "speed": 4.0, "windup": 0.45,
		"armor": Color(0.7, 0.85, 1.0), "cape": Color(0.95, 0.95, 1.0), "moves": ["strike", "lunge", "bolt", "leap"],
		"lore": "Pilgrims walk a thousand miles to touch his robes. He smiles at you as if he knows you.\nEvery move he has, faster."},
	{"title": "THE DAWNBRINGER", "form": 3, "scale": 1.2, "hp": 350.0, "strike": 33.0, "speed": 4.3, "windup": 0.4,
		"armor": Color(1.0, 0.82, 0.4), "cape": Color(0.8, 0.12, 0.1), "moves": ["strike", "lunge", "bolt", "leap"],
		"lore": "Not a man any more. The morning itself, come for the last of the night.\nHe has your eyes."},
]

# Six branches of the Ascension tree, four perks each. Bought with Dread. They RESET every night,
# and each night's perks are 10% stronger than the last (asc_mult). Descriptions are built by perk_desc().
var PERKS := {
	"vigor": {"name": "Iron Throne", "desc": "+40 max Will", "cost": 35, "req": ""},
	"wrath": {"name": "Wrath", "desc": "+25% damage", "cost": 70, "req": "vigor"},
	"presence": {"name": "Crushing Presence", "desc": "He hesitates: his windup is 0.12s slower", "cost": 110, "req": "wrath"},
	"colossal": {"name": "Colossal Will", "desc": "+80 max Will", "cost": 150, "req": "presence"},
	"haste": {"name": "Quickened Malice", "desc": "-20% cooldowns", "cost": 35, "req": ""},
	"unreadable": {"name": "Unreadable", "desc": "He learns 25% slower", "cost": 75, "req": "haste"},
	"fog": {"name": "Mind Fog", "desc": "His reactions are 0.08s slower", "cost": 110, "req": "unreadable"},
	"misdirect": {"name": "Misdirection", "desc": "He learns nothing from hits within a fight", "cost": 150, "req": "fog"},
	"fleet": {"name": "Fleet Throne", "desc": "Lean 40% faster", "cost": 35, "req": ""},
	"afterimage": {"name": "Afterimage", "desc": "Blows you lean away from deal 15% instead of 30%", "cost": 70, "req": "fleet"},
	"phantom": {"name": "Phantom Step", "desc": "Leaning out of a blow staggers him for 0.6s", "cost": 110, "req": "afterimage"},
	"widedais": {"name": "Wide Dais", "desc": "You can lean 50% further", "cost": 140, "req": "phantom"},
	"harvest": {"name": "Dread Harvest", "desc": "+50% Dread earned", "cost": 30, "req": ""},
	"generous": {"name": "Generous Rites", "desc": "Rites cost 30 Dread", "cost": 60, "req": "harvest"},
	"fated": {"name": "Fated Hand", "desc": "The Rite needle moves 35% slower", "cost": 90, "req": "generous"},
	"bottomless": {"name": "Bottomless Rite", "desc": "Your first Rite after each of his deaths is free", "cost": 140, "req": "fated"},
	"talons": {"name": "Hardened Talons", "desc": "Parry window +0.1s", "cost": 35, "req": ""},
	"scale": {"name": "Obsidian Scale", "desc": "Parried blows deal 8% instead of 15%", "cost": 70, "req": "talons"},
	"riposte": {"name": "Riposte", "desc": "A parry staggers him for 1 second", "cost": 110, "req": "scale"},
	"bastion": {"name": "Iron Bastion", "desc": "Parry recovers 40% faster", "cost": 140, "req": "riposte"},
	"overflow": {"name": "Overflow", "desc": "Skills he does not know yet deal +30% damage", "cost": 40, "req": ""},
	"echo": {"name": "Echo", "desc": "15% chance a cast refunds its cooldown", "cost": 80, "req": "overflow"},
	"surge": {"name": "Arcane Surge", "desc": "Every 5th cast deals double damage", "cost": 120, "req": "echo"},
	"archmage": {"name": "Archmage", "desc": "+1 loadout slot", "cost": 160, "req": "surge"},
}

# Classes: each owns a set of skills (by school). Unlock with Crowns; your ACTIVE class grants its passive.
# The Rite of Summoning only draws from classes you have unlocked.
var CLASSES := {
	"pyro": {"name": "PYROMANCER", "school": "HELLFIRE", "icon": "fireball", "cost": 0, "color": Color(1.0, 0.45, 0.15), "passive": "Hellfire skills deal +25% damage"},
	"bone": {"name": "OSSUARCH", "school": "BONE", "icon": "spikes", "cost": 0, "color": Color(0.9, 0.85, 0.7), "passive": "+40 max Will"},
	"war": {"name": "WARLORD", "school": "WARLORD", "icon": "sweep", "cost": 25, "color": Color(0.85, 0.55, 0.4), "passive": "Leaning grazes deal 15%; you lean 50% faster"},
	"rime": {"name": "RIMEWARDEN", "school": "RIME", "icon": "bloom", "cost": 30, "color": Color(0.5, 0.9, 1.0), "passive": "Slowed, frozen or bound heroes take +30% damage"},
	"storm": {"name": "STORMCALLER", "school": "STORM", "icon": "lightning", "cost": 40, "color": Color(0.75, 0.8, 1.0), "passive": "-20% cooldowns on every skill"},
	"void": {"name": "VOIDWALKER", "school": "VOID", "icon": "well", "cost": 50, "color": Color(0.65, 0.3, 1.0), "passive": "He learns your skills 20% slower"},
	"blood": {"name": "BLOODPRIEST", "school": "BLOOD", "icon": "siphon", "cost": 60, "color": Color(0.9, 0.15, 0.25), "passive": "Heal 10% of all damage you deal"},
}

# Relics: one is restored with each memory (each demon passed). Permanent for the run.
var RELICS := {
	"sword": {"name": "Borrowed Sword", "desc": "+10% damage"},
	"ring": {"name": "Broken Oath-Ring", "desc": "Parry window +0.06s"},
	"laurel": {"name": "Champion's Laurel", "desc": "+30% Dread earned"},
	"censer": {"name": "Cracked Censer", "desc": "He learns 10% slower"},
	"ashes": {"name": "Saint's Ashes", "desc": "+25% max Will"},
	"dawn": {"name": "Ember of Dawn", "desc": "Everything, a little brighter"},
}

# Eternity: permanent upgrades bought with Crowns. They survive every prestige and every new run.
var ETERNITY := {
	"colossus": {"name": "Colossus", "desc": "+20% max Will", "costs": [8, 16, 28, 44, 64]},
	"might": {"name": "Tyrant's Might", "desc": "+12% damage", "costs": [10, 20, 34, 52, 75]},
	"grudge": {"name": "Ancient Grudge", "desc": "Begin each hero with +40 Dread", "costs": [6, 14, 26, 40, 60]},
	"fate": {"name": "Favored Fate", "desc": "Rite rare and legendary zones 30% wider", "costs": [12, 28, 50]},
	"unknowable": {"name": "Unknowable", "desc": "He needs 1 more fight to master each skill", "costs": [25, 55, 100]},
	"finger": {"name": "Fifth Finger", "desc": "+1 loadout slot", "costs": [40]},
	"reflex": {"name": "Titan's Reflex", "desc": "Parry window +0.08s", "costs": [10, 24, 45]},
}

var level := 1   # also the DAY / NIGHT number
var attempt := 1
var total_deaths := 0
var dread := 0.0
var owned := {}
var loadout: Array[String] = []
var fights := {}
var temp := {}
var perks := {}
var eclipse_active := false
var autoplay := false

# Permanent (survive prestige and reset_run)
var crowns := 0
var eternity := {}
var runs_completed := 0
var unlocked_classes := {"pyro": true, "bone": true}
var active_class := "pyro"
var codex := {}            # every skill you have ever held -> best rank reached (for Remembrance)
var tutorial_seen := {}    # one-time hints already shown
var free_rite := false     # Bottomless Rite
var cast_count := 0        # Arcane Surge

# Story / board (per run)
var board_tile := -1  # -1 = the starting plinth
var memories: Array[String] = []
var relics: Array[String] = []
var fragments := 0
var next_hero_poise := 0.0
var bonus_dread := 0.0

# The day: the city of Vael by daylight. Deeds done by day make you stronger on the board.
var day_time := 0.0          # 0..1 through the day
var deeds: Array[String] = []  # day bosses slain (ids), whole run
var day_boss_slain := false
var weapon := "shortsword"   # the blade you carry by day (dialogue.gd WEAPONS)
var weapon_tune := 0         # aether tuning from Liore (+20% weapon damage each)
var kindness := 0            # dread given away / tribute refused
var cruelty := 0             # tribute demanded
var npc_met := {}
var tonight_will := 0.0      # tavern drinks: bonus Will for tonight only
var hints_seen := {}
var revealed := false        # the player knows who the Stranger is
# Your playstyle, watched all run long by the Stranger (and, within a fight, by the hero).
var style := {"casts": {}, "parries": 0, "grazes": 0, "hits": 0, "total_casts": 0, "fight_time": 0.0}
var fight_parries := 0
var fight_grazes := 0

# Per-hero stats
var level_damage := 0.0
var level_parries := 0
var level_skills_used := {}
var attempt_exposure := {}
var level_flawless := false
var pending_lessons: Array = []
var last_crowns: Array = []
var last_crowns_total := 0
var last_stars := 0
var checkpoint := {}


func _ready() -> void:
	reset_run()


## A fresh run. Crowns and Eternity are kept: that is the point of them.
func reset_run() -> void:
	level = 1
	attempt = 1
	total_deaths = 0
	owned = {"fireball": 1, "slam": 1, "spikes": 1}
	loadout = ["fireball", "slam", "spikes"]
	perks = {}
	board_tile = -1
	deeds = []
	day_boss_slain = false
	weapon = "shortsword"
	weapon_tune = 0
	kindness = 0
	cruelty = 0
	npc_met = {}
	dread = 0.0
	tonight_will = 0.0
	revealed = false
	day_time = 0.0
	style = {"casts": {}, "parries": 0, "grazes": 0, "hits": 0, "total_casts": 0, "fight_time": 0.0}
	memories = []
	relics = []
	fragments = 0
	next_hero_poise = 0.0
	bonus_dread = 0.0
	_new_hero_reset()


func _new_hero_reset() -> void:
	# Your skills, ranks and Ascension perks are kept; only Dread and his memory start over.
	# Dread you did not spend carries into the day (and the day's Dread into the night).
	dread += 40.0 * eternity_level("grudge") + bonus_dread
	bonus_dread = 0.0
	fights = {}
	temp = {}
	eclipse_active = false
	level_damage = 0.0
	level_parries = 0
	level_skills_used = {}
	attempt_exposure = {}
	level_flawless = false
	pending_lessons = []
	checkpoint = {}


# --- Lookups ------------------------------------------------------------------

func skill(id: String) -> Dictionary:
	return SKILLS[id]


func max_level() -> int:
	return mini(MAX_LEVEL, HEROES.size())


func hero_data() -> Dictionary:
	return HEROES[mini(level, HEROES.size()) - 1]


func level_data() -> Dictionary:
	return hero_data()


func next_hero_data() -> Dictionary:
	return HEROES[mini(level + 1, HEROES.size()) - 1]


func has_move(move: String) -> bool:
	return hero_data()["moves"].has(move)


func rank(id: String) -> int:
	return owned.get(id, 0)


func eternity_level(id: String) -> int:
	return eternity.get(id, 0)


func loadout_size() -> int:
	return BASE_LOADOUT + eternity_level("finger") + (1 if perks.has("archmage") else 0)


func class_of(id: String) -> String:
	return SCHOOL_CLASS[SKILLS[id]["school"]]


func class_skills(cid: String) -> Array[String]:
	var out: Array[String] = []
	for id in SKILLS:
		if class_of(id) == cid:
			out.append(id)
	return out


func class_unlocked(cid: String) -> bool:
	return unlocked_classes.has(cid)


func unlock_class(cid: String, discount: float = 1.0) -> bool:
	var cost := int(CLASSES[cid]["cost"] * discount)
	if class_unlocked(cid) or crowns < cost:
		return false
	crowns -= cost
	unlocked_classes[cid] = true
	print("[CLASS] unlocked %s" % cid)
	return true


func set_active_class(cid: String) -> void:
	if class_unlocked(cid):
		active_class = cid


func has_relic(r: String) -> bool:
	return relics.has(r)


func damage_for(id: String) -> float:
	var d: float = SKILLS[id]["damage"]
	d *= 1.0 + 0.15 * (rank(id) - 1)
	d *= 1.0 + 0.12 * eternity_level("might")
	d *= 1.0 + 0.1 * deeds.size()
	d *= 1.0 + 0.05 * (weapon_tier() - 1)
	if perks.has("wrath"):
		d *= 1.0 + 0.25 * asc_mult()
	if active_class == "pyro" and class_of(id) == "pyro":
		d *= 1.25
	if has_relic("sword"):
		d *= 1.1
	if perks.has("overflow") and tier(get_mastery(id)) == 0:
		d *= 1.0 + 0.3 * asc_mult()
	return d


func cooldown_for(id: String) -> float:
	var c: float = SKILLS[id]["cooldown"]
	if perks.has("haste"):
		c *= maxf(0.4, 1.0 - 0.2 * asc_mult())
	if active_class == "storm":
		c *= 0.8
	return c


func boss_max_hp() -> float:
	var hp := 150.0 + (40.0 * asc_mult() if perks.has("vigor") else 0.0) + (40.0 if active_class == "bone" else 0.0) + (80.0 * asc_mult() if perks.has("colossal") else 0.0)
	hp += 25.0 * deeds.size() + tonight_will
	hp *= 1.0 + 0.2 * eternity_level("colossus")
	if has_relic("ashes"):
		hp *= 1.25
	return hp


func lean_speed() -> float:
	return 3.2 * (1.5 if active_class == "war" else 1.0) * (1.0 + 0.4 * asc_mult() if perks.has("fleet") else 1.0)


# --- Parry --------------------------------------------------------------------

func parry_window() -> float:
	return 0.24 + (0.1 * asc_mult() if perks.has("talons") else 0.0) + 0.08 * eternity_level("reflex") + (0.06 if has_relic("ring") else 0.0)


## Your parry is up for this many ticks (it opens on the tick after you press it).
func parry_ticks() -> int:
	return maxi(1, ceili(parry_window() / TICK - 0.01))


func parry_cd_ticks() -> int:
	return maxi(2, ceili(parry_cooldown() / TICK - 0.01))


func cooldown_ticks(id: String) -> int:
	return maxi(GCD_TICKS, ceili(cooldown_for(id) / TICK - 0.01))


## Ascension perks reset every night; each night they are 10% stronger.
func asc_mult() -> float:
	return 1.0 + 0.1 * (level - 1)


func perk_desc(id: String) -> String:
	var m := asc_mult()
	match id:
		"vigor": return "+%d max Will" % int(40 * m)
		"wrath": return "+%d%% damage" % int(25 * m)
		"presence": return "His windup is %d tick slower" % (1 if m < 1.5 else 2)
		"colossal": return "+%d max Will" % int(80 * m)
		"haste": return "-%d%% cooldowns" % int(minf(60.0, 20 * m))
		"unreadable": return "He learns %d%% slower" % int(minf(60.0, 25 * m))
		"fog": return "His reactions are %d%% slower" % int(30 * m)
		"misdirect": return "He learns nothing from hits within a fight"
		"fleet": return "Lean %d%% faster" % int(40 * m)
		"afterimage": return "Leaned blows deal %d%% instead of 30%%" % int(round(graze_taken_base(true) * 100))
		"phantom": return "Leaning out of a blow staggers him %d ticks" % int(round(2 * m + 0.4))
		"widedais": return "You can lean %d%% further" % int(50 * m)
		"harvest": return "+%d%% Dread earned" % int(50 * m)
		"generous": return "Rites cost %d Dread" % rite_discount_cost()
		"fated": return "The Rite needle moves %d%% slower" % int(minf(60.0, 35 * m))
		"bottomless": return "Your first Rite after each of his deaths is free"
		"talons": return "Parry window +%.2fs" % (0.1 * m)
		"scale": return "Parried blows deal %d%% instead of 15%%" % int(round(parry_taken_base(true) * 100))
		"riposte": return "A parry staggers him %d ticks" % int(round(4 * m))
		"bastion": return "Parry recovers %d%% faster" % int(minf(70.0, 40 * m))
		"overflow": return "Skills he does not know yet deal +%d%% damage" % int(30 * m)
		"echo": return "%d%% chance a cast refunds its cooldown" % int(15 * m)
		"surge": return "Every 5th cast deals %.1fx damage" % (1.0 + m)
		"archmage": return "+1 loadout slot"
	return PERKS[id]["desc"]


func rite_discount_cost() -> int:
	return maxi(10, int(round(30.0 / asc_mult())))


## Fraction of a parried blow you still take: he only hits a lesser part of you.
func parry_taken() -> float:
	return parry_taken_base(perks.has("scale"))


func parry_taken_base(scale: bool) -> float:
	return maxf(0.03, 0.08 / asc_mult()) if scale else 0.15


## Fraction you still take when you lean out of his blow (a graze).
func graze_taken() -> float:
	var g := graze_taken_base(perks.has("afterimage"))
	if active_class == "war":
		g *= 0.5
	return g


func graze_taken_base(afterimage: bool) -> float:
	return maxf(0.05, 0.15 / asc_mult()) if afterimage else 0.3


func parry_cooldown() -> float:
	return 0.9 * (maxf(0.3, 1.0 - 0.4 * asc_mult()) if perks.has("bastion") else 1.0)


func lean_limit() -> float:
	return 2.6 * (1.0 + 0.5 * asc_mult() if perks.has("widedais") else 1.0)


# --- The hero -----------------------------------------------------------------

func hero_stats() -> Dictionary:
	# Every death compounds (x1.2 per death). This exponential growth is what guarantees he wins.
	var H := hero_data()
	var a := float(attempt - 1)
	var g := pow(1.2, a)
	return {
		"hp": H["hp"] * g,
		"strike": H["strike"] * g,
		"speed": H["speed"] + 0.18 * a,
		"windup": maxf(0.3, H["windup"] - 0.03 * a),
		"armor": H["armor"],
		"cape": H["cape"],
		"form": H["form"],
		"scale": H["scale"],
	}


## Generic chance to react even to something he has never seen.
func hero_instinct() -> float:
	return 0.04 * (attempt - 1) + 0.06 * (level - 1)


## Chance he rolls or sidesteps out of a blow even without knowing the skill (proactive dodge).
func hero_evasion() -> float:
	return clampf(0.08 + 0.07 * (attempt - 1) + 0.06 * (level - 1), 0.0, 0.65)


## His windup in ticks (Crushing Presence adds ticks).
func windup_ticks(windup: float) -> int:
	var extra := 0
	if perks.has("presence"):
		extra = 1 if asc_mult() < 1.5 else 2
	return maxi(2, roundi(windup / TICK)) + extra


## Chance he shrugs off a hit instead of being staggered out of his swing.
func hero_poise() -> float:
	return clampf(0.15 * (attempt - 1) + 0.15 * (level - 1) + next_hero_poise, 0.0, 0.9)


## How far you can lean away mid-swing before he still connects. Later heroes track you better.
func whiff_tolerance() -> float:
	return 1.2 + 0.2 * (level - 1) + 0.06 * (attempt - 1)


# --- Mastery (per-fight exponential curve) -------------------------------------

func fights_to_master() -> float:
	return BASE_FIGHTS + eternity_level("unknowable")


func mastery_from_fights(n: float) -> float:
	var f := fights_to_master()
	return MASTERY_CAP * clampf((exp(CURVE_K * n) - 1.0) / (exp(CURVE_K * f) - 1.0), 0.0, 1.0)


func base_mastery(id: String) -> float:
	return mastery_from_fights(fights.get(id, 0.0))


func get_mastery(id: String) -> float:
	return clampf(base_mastery(id) + temp.get(id, 0.0), 0.0, MASTERY_CAP)


func fights_seen(id: String) -> float:
	return fights.get(id, 0.0)


func tier(m: float) -> int:
	if m >= 0.75:
		return 3
	if m >= 0.4:
		return 2
	if m >= 0.15:
		return 1
	return 0


## Called by every attack the moment he sees it.
func expose(id: String) -> void:
	attempt_exposure[id] = attempt_exposure.get(id, 0) + 1


## Within a fight he picks up a little from every hit; he keeps none of it when he dies.
func learn(id: String, hit: bool, _countered: bool) -> void:
	if hit and not perks.has("misdirect"):
		temp[id] = minf(temp.get(id, 0.0) + 0.05, 0.25)


func add_dread(amount: float) -> void:
	if perks.has("harvest"):
		amount *= 1.0 + 0.5 * asc_mult()
	if has_relic("laurel"):
		amount *= 1.3
	dread += amount


func on_hero_hit(id: String, dmg: float) -> void:
	level_damage += dmg
	add_dread(dmg * 0.25)


func on_parry() -> void:
	level_parries += 1
	fight_parries += 1
	style["parries"] += 1
	add_dread(4.0)


func on_graze() -> void:
	fight_grazes += 1
	style["grazes"] += 1


func on_cast(id: String) -> void:
	style["casts"][id] = style["casts"].get(id, 0) + 1
	style["total_casts"] += 1


## The skill you lean on most (the Stranger's first target).
func favorite_skill() -> String:
	var best := ""
	var n := -1
	for id in style["casts"]:
		if style["casts"][id] > n and owned.has(id):
			n = style["casts"][id]
			best = id
	if best == "" and not loadout.is_empty():
		best = loadout[0]
	return best


## What kind of fighter you are: "parry", "lean", or "caster".
func playstyle() -> String:
	var p: int = style["parries"]
	var g: int = style["grazes"]
	if p >= g * 1.5 and p >= 8:
		return "parry"
	if g > p and g >= 6:
		return "lean"
	return "caster"


func on_hero_death() -> void:
	add_dread(20.0)
	# He dies, and remembers: one fight of experience against every skill he saw.
	var rate := maxf(0.4, 1.0 - 0.25 * asc_mult()) if perks.has("unreadable") else 1.0
	if active_class == "void":
		rate *= 0.8
	if has_relic("censer"):
		rate *= 0.9
	pending_lessons = []
	for id in attempt_exposure:
		var before := tier(base_mastery(id))
		fights[id] = fights.get(id, 0.0) + rate
		var after := tier(base_mastery(id))
		if after > before and after >= 2:
			pending_lessons.append([id, after])
			mastery_milestone.emit(id, after)
	attempt_exposure = {}
	temp = {}
	free_rite = perks.has("bottomless")
	fight_parries = 0
	fight_grazes = 0
	attempt += 1
	total_deaths += 1
	print("[DEATH] L%d hero died, next attempt %d, dread %d, mastery %s" % [level, attempt, int(dread), _mastery_str()])


func on_boss_defeated(flawless: bool) -> void:
	level_flawless = flawless
	last_stars = current_stars()
	_compute_crowns()
	print("[BOSS DEFEATED] L%d after %d hero deaths, stars=%d, flawless=%s, crowns=%d" % [level, attempt - 1, last_stars, flawless, last_crowns_total])


# --- Prestige -----------------------------------------------------------------

func _compute_crowns() -> void:
	var deaths := attempt - 1
	last_crowns = [
		["HERO DEATHS CAUSED: %d" % deaths, deaths * (2 + level)],
		["DAMAGE DEALT: %d" % int(level_damage), int(level_damage / 200.0)],
		["BLOWS PARRIED: %d" % level_parries, level_parries],
		["%s CONQUERED YOU" % hero_data()["title"], 8 * level],
	]
	if last_stars > 0:
		last_crowns.append(["%s EARNED" % "★".repeat(last_stars), 8 * last_stars * level])
	if day_boss_slain:
		last_crowns.append(["A DEED DONE BY DAY", 6 * level])
	if level_flawless:
		last_crowns.append(["HE NEVER BLED (FLAWLESS)", 10])
	last_crowns_total = 0
	for row in last_crowns:
		last_crowns_total += int(row[1])


## Bank the Crowns and bring the next, tougher hero. Dread, Ascension and his memory reset.
func prestige() -> void:
	crowns += last_crowns_total
	next_hero_poise = 0.0
	for id in owned:
		_remember(id)
	owned = {"fireball": 1, "slam": 1, "spikes": 1}
	loadout = ["fireball", "slam", "spikes"]
	perks = {}  # Ascension resets every night; tomorrow night's perks are 10% stronger
	level += 1
	attempt = 1
	day_boss_slain = false
	tonight_will = 0.0
	day_time = 0.0
	_new_hero_reset()
	print("[PRESTIGE] now L%d, crowns %d" % [level, crowns])


func is_final_hero() -> bool:
	return level >= max_level()


# --- Stars & checkpoints --------------------------------------------------------

func stars_for(deaths: int) -> int:
	var n := 0
	for d in STAR_DEATHS:
		if deaths >= d:
			n += 1
	return n


func current_stars() -> int:
	return stars_for(attempt - 1)


func is_checkpoint_attempt() -> bool:
	return (attempt - 1) % CHECKPOINT_EVERY == 0


func checkpoint_attempt() -> int:
	return checkpoint.get("attempt", 1)


## Snapshot everything a failed hero would roll back (not Crowns or Eternity).
func save_checkpoint() -> void:
	checkpoint = {
		"attempt": attempt, "total_deaths": total_deaths, "dread": dread,
		"owned": owned.duplicate(), "loadout": loadout.duplicate(), "fights": fights.duplicate(),
		"perks": perks.duplicate(), "level_damage": level_damage, "level_parries": level_parries,
		"level_skills_used": level_skills_used.duplicate(),
	}
	print("[CHECKPOINT] saved at L%d fight %d" % [level, attempt])


func restore_checkpoint() -> void:
	if checkpoint.is_empty():
		return
	attempt = checkpoint["attempt"]
	total_deaths = checkpoint["total_deaths"]
	dread = checkpoint["dread"]
	owned = checkpoint["owned"].duplicate()
	loadout.assign(checkpoint["loadout"])
	fights = checkpoint["fights"].duplicate()
	perks = checkpoint["perks"].duplicate()
	level_damage = checkpoint["level_damage"]
	level_parries = checkpoint["level_parries"]
	level_skills_used = checkpoint["level_skills_used"].duplicate()
	temp = {}
	attempt_exposure = {}
	eclipse_active = false
	fight_parries = 0
	fight_grazes = 0
	print("[CHECKPOINT] restored L%d fight %d" % [level, attempt])


func eternity_cost(id: String) -> int:
	var costs: Array = ETERNITY[id]["costs"]
	var lv := eternity_level(id)
	return costs[lv] if lv < costs.size() else -1


func buy_eternity(id: String) -> bool:
	var cost := eternity_cost(id)
	if cost < 0 or crowns < cost:
		return false
	crowns -= cost
	eternity[id] = eternity_level(id) + 1
	print("[ETERNITY] %s -> %d" % [id, eternity[id]])
	return true


# --- Gacha --------------------------------------------------------------------

func pull_cost() -> int:
	if free_rite:
		return 0
	return rite_discount_cost() if perks.has("generous") else PULL_COST


func rite_speed_mult() -> float:
	return maxf(0.4, 1.0 - 0.35 * asc_mult()) if perks.has("fated") else 1.0


## [legendary half-width, rare half-width] of the Rite bar zones.
func rite_zones() -> Array:
	var w := 1.0 + 0.3 * eternity_level("fate")
	return [0.05 * w, minf(0.17 * w, 0.45)]


func can_pull() -> bool:
	return dread >= pull_cost()


## Spend Dread on a rite. Rarity comes from the minigame. Duplicates reforge the skill:
## +1 rank and he forgets two fights' worth of what he knew about it.
func pull(rarity: int) -> Dictionary:
	dread -= pull_cost()
	free_rite = false
	var pool: Array[String] = []
	for id in SKILLS:
		if SKILLS[id]["rarity"] == rarity and class_unlocked(class_of(id)):
			pool.append(id)
	if pool.is_empty():
		for id in SKILLS:
			if class_unlocked(class_of(id)):
				pool.append(id)
	var id: String = pool.pick_random()
	var dup := owned.has(id)
	if dup:
		owned[id] = mini(owned[id] + 1, MAX_RANK)
		fights[id] = maxf(0.0, fights.get(id, 0.0) - 2.0)
	else:
		owned[id] = 1
		if loadout.size() < loadout_size():
			loadout.append(id)
	_remember(id)
	print("[PULL] %s -> %s rank %d (dup=%s)" % [RARITY_NAMES[rarity], id, owned[id], dup])
	return {"id": id, "dup": dup, "rank": owned[id], "rarity": rarity}


func toggle_loadout(id: String) -> void:
	if loadout.has(id):
		if loadout.size() > 1:
			loadout.erase(id)
	elif loadout.size() < loadout_size():
		loadout.append(id)


func perk_available(id: String) -> bool:
	var req: String = PERKS[id]["req"]
	return not perks.has(id) and (req == "" or perks.has(req))


func buy_perk(id: String) -> bool:
	var cost: float = PERKS[id]["cost"]
	if not perk_available(id) or dread < cost:
		return false
	dread -= cost
	perks[id] = true
	print("[PERK] %s" % id)
	return true


func _mastery_str() -> String:
	var parts: Array[String] = []
	for id in fights:
		parts.append("%s=%.0f/%.2f" % [id, fights[id], base_mastery(id)])
	return ", ".join(parts)


# --- Story / board effects ------------------------------------------------------

## Apply a board event reward. Returns a short line describing what happened.
func apply_effect(effect: String) -> String:
	var parts := effect.split(":")
	var kind := parts[0]
	var amount := float(parts[1]) if parts.size() > 1 else 0.0
	match kind:
		"crowns":
			crowns += int(amount)
			return "+%d CROWNS" % int(amount)
		"dread":
			bonus_dread += amount
			return "+%d DREAD WHEN THE NEXT DEMON COMES" % int(amount)
		"skill":
			var pool: Array[String] = []
			for id in SKILLS:
				if class_unlocked(class_of(id)) and not owned.has(id):
					pool.append(id)
			if pool.is_empty():
				return apply_effect("rank")
			var id: String = pool.pick_random()
			owned[id] = 1
			_remember(id)
			if loadout.size() < loadout_size():
				loadout.append(id)
			return "NEW SKILL: %s" % str(SKILLS[id]["name"]).to_upper()
		"rank":
			var ids: Array = owned.keys().filter(func(k): return owned[k] < MAX_RANK)
			if ids.is_empty():
				return apply_effect("crowns:10")
			var id: String = ids.pick_random()
			owned[id] += 1
			_remember(id)
			return "%s REFORGED TO RANK %d" % [str(SKILLS[id]["name"]).to_upper(), owned[id]]
		"curse":
			next_hero_poise += amount
			return "THE NEXT DEMON STANDS FIRMER (+%d%% POISE)" % int(amount * 100)
		"fragment":
			fragments += 1
			return "MEMORY FRAGMENT FOUND"
	return ""


func restore_memory(chapter: int, relic: String) -> void:
	memories.append(str(chapter))
	if relic != "" and not relics.has(relic):
		relics.append(relic)


# --- Remembrance: skills reset each chapter; you may carry some back, stronger as you ascend ---------

func _remember(id: String) -> void:
	codex[id] = maxi(codex.get(id, 0), owned.get(id, 1))


func remembrance_slots() -> int:
	return 2 + level / 2


## The strongest version you may recall this chapter (ascending unlocks harder-hitting versions).
func remembrance_rank_cap() -> int:
	return mini(MAX_RANK, level)


func remembrance_rank(id: String) -> int:
	return clampi(codex.get(id, 1), 1, remembrance_rank_cap())


func remembrance_choices() -> Array[String]:
	var out: Array[String] = []
	for id in codex:
		if class_unlocked(class_of(id)):
			out.append(id)
	out.sort_custom(func(a, b): return remembrance_rank(a) > remembrance_rank(b))
	return out


func apply_remembrance(ids: Array) -> void:
	for id in ids:
		owned[id] = remembrance_rank(id)
		if not loadout.has(id):
			if loadout.size() < loadout_size():
				loadout.append(id)
			else:
				loadout[loadout.size() - 1] = id
	print("[REMEMBRANCE] %s" % [ids])


func roman(n: int) -> String:
	return ["", "I", "II", "III", "IV", "V"][clampi(n, 0, 5)]


## "Hellfire Orb III": the version you hold.
func skill_title(id: String) -> String:
	var r := rank(id)
	return str(SKILLS[id]["name"]) + (" " + roman(r) if r > 1 else "")


## Hands: how far the King has come back to himself (0 = corrupted, 1 = enlightened).
func purity() -> float:
	return clampf(memories.size() / 6.0, 0.0, 1.0)


func weapon_tier() -> int:
	var W = load("res://scripts/dialogue.gd").WEAPONS
	return W[weapon]["tier"] if W.has(weapon) else 1


## The Stranger takes on everything your hands let go of.
func stranger_corruption() -> float:
	return purity()


func is_final_night() -> bool:
	return level > max_level()
