extends RefCounted
## Everything people say in Vael, the city you walk by day, and at the table by night.
##
## TONE follows your purity (GameState.purity): at first you are the Hollow King and the city is
## terrified of you (0 = FEAR). As your hands purify they grow wary, then warm (1 = WARY), and in
## the end they treat you as a saint (2 = SAINT). Every NPC has a greeting for each tone.
##
## The STRANGER is the purest version of you. Every NPC hint below quietly says so (he walks like
## you, pays in coins with your younger face, is in two places at once). The player is told outright
## on night 5, at about 75% of the way through.

const TONE_NAMES := ["FEAR", "WARY", "SAINT"]


static func tone() -> int:
	var p := GameState.purity()
	if p < 0.3:
		return 0
	if p < 0.6:
		return 1
	return 2


# --- Weapons: the city's tech rises a little every day, and so do its blades --------------------
# tier = the day it first appears in shops / chests. dmg per swing, ticks between swings, reach.
const WEAPONS := {
	"shortsword": {"name": "Rusted Shortsword", "tier": 1, "dmg": 14.0, "ticks": 3, "reach": 2.3, "cost": 0,
		"color": Color(0.6, 0.55, 0.5), "glow": 0.0, "kind": "sword", "desc": "Iron, nicked and brown. Every king starts somewhere."},
	"runeblade": {"name": "Runed Longsword", "tier": 2, "dmg": 20.0, "ticks": 3, "reach": 2.6, "cost": 40,
		"color": Color(0.45, 0.8, 1.0), "glow": 1.5, "kind": "sword", "desc": "Old steel, new runes. They hum when it is drawn."},
	"cogaxe": {"name": "Cog-Axe", "tier": 3, "dmg": 30.0, "ticks": 4, "reach": 2.4, "cost": 70,
		"color": Color(0.85, 0.6, 0.25), "glow": 1.0, "kind": "axe", "desc": "A geared head that spins up as it falls."},
	"arcbrand": {"name": "Arcbrand", "tier": 4, "dmg": 30.0, "ticks": 2, "reach": 2.7, "cost": 110,
		"color": Color(0.6, 0.75, 1.0), "glow": 3.0, "kind": "sword", "desc": "Lightning caught in a channel of steel. Fast."},
	"halberd": {"name": "Phase Halberd", "tier": 5, "dmg": 46.0, "ticks": 3, "reach": 3.6, "cost": 160,
		"color": Color(0.75, 0.4, 1.0), "glow": 3.0, "kind": "axe", "desc": "The blade flickers half a step out of the world."},
	"sunedge": {"name": "Sunforged Edge", "tier": 6, "dmg": 60.0, "ticks": 2, "reach": 3.0, "cost": 230,
		"color": Color(1.0, 0.8, 0.4), "glow": 5.0, "kind": "sword", "desc": "Plasma in a gold frame. The forge-priests call it the morning."},
}


# --- Day bosses: the people and things that shaped each past self, still loose in Vael ----------
const DAY_BOSSES := [
	{"id": "mordrek", "name": "MORDREK THE ASH-CAPTAIN", "lair": "farm", "hp": 260.0, "dmg": 14.0, "speed": 3.2, "kind": "brute",
		"color": Color(0.5, 0.25, 0.15), "tech": Color(1.0, 0.4, 0.1),
		"intro": "A raider in scorched mail, still wearing the smell of smoke.",
		"defeat": "Mordrek laughs through blood: \"The farm boy? He ran off to the capital to be a hero. We burned it while he was gone.\""},
	{"id": "warden", "name": "THE BRIDGE WARDEN", "lair": "bridge", "hp": 360.0, "dmg": 18.0, "speed": 2.8, "kind": "shield",
		"color": Color(0.3, 0.35, 0.55), "tech": Color(0.4, 0.7, 1.0),
		"intro": "The old king's enforcer, an iron shell with a lamp for a heart. He guards the bridge you once abandoned.",
		"defeat": "The Warden's lamp gutters: \"ORDER... HOLD... THE BRIDGE... TRAITOR... CORVIN.\""},
	{"id": "pitmaster", "name": "THE PIT MASTER", "lair": "pit", "hp": 420.0, "dmg": 18.0, "speed": 3.4, "kind": "summoner",
		"color": Color(0.6, 0.45, 0.2), "tech": Color(1.0, 0.8, 0.3),
		"intro": "He ran the Sunfield fights. He still sells tickets to anyone who will bleed.",
		"defeat": "\"I made you, Lion. I gave you the name. Don't you remember who you were before I sold you?\""},
	{"id": "inquisitor", "name": "THE HIGH INQUISITOR", "lair": "pyre", "hp": 480.0, "dmg": 20.0, "speed": 3.0, "kind": "caster",
		"color": Color(0.75, 0.75, 0.8), "tech": Color(1.0, 0.85, 0.5),
		"intro": "Brother Ashe's teacher. He hurls holy fire from a censer wired with aether-coils.",
		"defeat": "\"You were my best student, Ashe. You burned them faster than I ever could.\""},
	{"id": "prophet", "name": "THE GILDED PROPHET", "lair": "shrine", "hp": 560.0, "dmg": 22.0, "speed": 3.8, "kind": "blinker",
		"color": Color(0.85, 0.7, 0.3), "tech": Color(1.0, 0.95, 0.6),
		"intro": "He preaches in a voice that is not his own. It is the crown's voice.",
		"defeat": "\"The crown chose you, Alder. It whispered your name to me first. It is whispering still.\""},
	{"id": "herald", "name": "THE CROWN'S HERALD", "lair": "spire", "hp": 680.0, "dmg": 25.0, "speed": 3.6, "kind": "brute",
		"color": Color(0.35, 0.1, 0.4), "tech": Color(1.0, 0.2, 0.3),
		"intro": "A knight of black glass, carrying the old tyrant's banner. It speaks for the thing on your head.",
		"defeat": "\"The Dawnbringer killed the tyrant. And then he put on the crown. We were so proud of him.\""},
]


# --- Where you wake each morning ---------------------------------------------------------------
const WAKE := [
	["fountain", "You wake on the steps of the fountain, frost on your cloak. The city is already watching you."],
	["stables", "You wake in the hay of the Watch stables. A horse stares at you. You feel... lighter."],
	["bridge", "You wake beneath the old bridge, the river loud in your ears. Your hands are warmer than yesterday."],
	["cathedral", "You wake on a pew in the Cathedral of Gears. Someone has covered you with a blanket."],
	["wall", "You wake on the wall-walk, the sun on your face. You do not remember the last time that felt good."],
	["cog", "You wake on a bench in the Rusted Cog. Greta has left you water. And a note: \"for the saint.\""],
	["gate", "You wake at the east gate. The guards are kneeling. Not in fear."],
]


# --- The Stranger, at the table each night -----------------------------------------------------
# index = night - 1. Night 5 is the reveal. Night 7 is the last night (no board: the final fight).
const STRANGER_NIGHT := [
	["A man in white, hood low, sits at the corner table as if it were his. A board waits between you.",
		"\"Evening. You look like someone who's lost something. Sit. Play. It helps, I promise. Even when you lose.\""],
	["He is already seated, shuffling the pieces with his left hand first. The same way you do.",
		"\"Back again. You always come back. ...No, I didn't follow you. I'm just always where you end up.\""],
	["There is grey in the white of his robe tonight, like ash that will not brush off.",
		"\"I was at the bridge too, you know. Rain like needles. ...What? Everyone was at the bridge.\""],
	["His sleeves are stained. When he sets your piece down, you see a thorn break the skin of his wrist.",
		"\"Funny. Every tavern you walk into, I'm already sitting in. Every road you take, I took first.\""],
	["His robe is grey now, his hands dark and veined. Red light behind his hood. Then he lowers it.",
		"\"Still don't see it? Look at my hands. Look at yours. Every bit of rot that leaves you comes here.\""],
	["Nothing of the white remains. He smiles with your mouth.",
		"\"One more of you to remember. Then it's just us. Me, and me.\""],
	["No board tonight. The Stranger stands, and the tavern dissolves around you.",
		"\"I've watched every move you've made. Every night. Every habit. Let's see if you can surprise yourself.\""],
]

const REVEAL := "You see it now. Behind the hood is your face: the one you had before the crown. His hands are your hands, the way they were when you took the throne: veined, thorned, shackled.\n\nHe is you. The part of you that is pure enough to carry the rot away, night after night, so that you could wake up a little cleaner. That is how he finds you at every dusk, wherever you are: he never left.\n\n\"Took you long enough,\" he says, in your voice."


# --- Hints in the city: easter eggs that the Stranger is you ------------------------------------
# By day (index = day - 1). Any NPC asked about "the man in white" picks from that day's list.
const STRANGER_HINTS := [
	["A man in white bought bread here at dawn. Walked just like you do. Same limp, other leg.",
		"He paid me in old coins. The face on them... it looked like you. Younger.",
		"I saw a man in white at the east gate and at the cathedral, the same minute. I swear on my mother."],
	["The man in white asked if you'd eaten. Who asks that about a tyrant?",
		"He hums the song the farm boys sing in the Ashen Vale. You hummed it yesterday, when you thought no one heard.",
		"He signs his tab at the Flagon with a W. Then crosses it out."],
	["He has a scar on his palm. Same as the one on yours. I looked. I'm sorry, I looked.",
		"He sat by the fountain all morning and never cast a reflection. Then again, nor do you, some days.",
		"The Watch has a sketch of him. Captain says it's no use. \"Looks like the King,\" he says, \"if the King had slept.\""],
	["He's going grey, the man in white. Faster than a man should.",
		"His hands are going dark. Like yours were. ...Like yours were.",
		"He told Pip he'd been carrying something heavy for a friend. Pip asked who. He pointed at you."],
	["The man in the grey robe. He wears your old ring. The one you threw in the river.",
		"I don't think he's a man. I think he's what's left when a man puts something down.",
		"Every night he leaves the Flagon after you. Every morning he's never been seen leaving at all."],
	["He's not the man in white any more, saint. He's you, from before. Everyone can see it but you.",
		"Be kind to him tonight. He's had a hard week. He's had your week.",
		"He came to the cathedral and asked Sister Ivy to pray for the King. Then for himself. Same prayer."],
	["Tonight's the night, isn't it? The whole city can feel it.",
		"Whoever wins tonight, saint, it's you that walks out.",
		"He left a note at the Flagon: \"Tell him I'm proud of him. Then tell him I won't go easy.\""],
]

# Scrawled on walls around Vael. Read them with E.
const GRAFFITI := [
	"HE IS ALWAYS WHERE YOU ARE",
	"THE KING SLEEPS. WHO WALKS AT NIGHT?",
	"W WAS HERE",
	"WHITE AT DUSK, BLACK AT DAWN",
	"YOU CANNOT OUTRUN A MAN WHO IS ALREADY HOME",
	"ASK HIM HIS NAME. THEN ASK YOURS.",
]


# --- People of Vael ----------------------------------------------------------------------------
# greet[tone], services shown as choices. "spot" is where they stand (overworld.gd places them).
const NPCS := {
	"marta": {"name": "MARTA, THE BAKER", "spot": "bakery", "look": [Color(0.8, 0.6, 0.45), Color(0.9, 0.85, 0.75)],
		"greet": ["P-please, my lord, take the bread. Take all of it. Just... don't look at my children.",
			"You again. You paid, last time. Didn't expect that. Bread?",
			"Blessed one! Fresh loaves, still warm. No, no coin. Just stay a moment. The children want to see you."],
		"service": "bread"},
	"hennik": {"name": "OLD HENNIK, THE SMITH", "spot": "forge", "look": [Color(0.35, 0.25, 0.2), Color(0.25, 0.22, 0.2)],
		"greet": ["I make blades for the Watch, my lord. Take what you need. Only... don't burn the forge.",
			"Steel's steel. Aether-steel's better. Pay, and it's yours.",
			"I forged this one thinking of you. The runes sang while I worked. They never sang before."],
		"service": "weapons"},
	"ivy": {"name": "SISTER IVY", "spot": "cathedral", "look": [Color(0.2, 0.2, 0.3), Color(0.9, 0.9, 0.95)],
		"greet": ["Stay back. This is holy ground. ...Saints protect me. Saints protect me.",
			"Even you may pray. I will not stop you. I may even pray with you.",
			"The light bends toward you, my lord. I can see it from across the nave. Kneel with me?"],
		"service": "bless"},
	"pip": {"name": "PIP, A STREET CHILD", "spot": "alley", "look": [Color(0.45, 0.35, 0.25), Color(0.5, 0.4, 0.3)], "small": true,
		"greet": ["(The child shrinks into the wall.) Mum says if I see the hollow man I run. I can't run. My leg.",
			"You gave me a coin yesterday. Are you still scary? You look less scary.",
			"Everyone says you glow now! Can I touch your hand? It's warm! It's actually warm!"],
		"service": "give"},
	"rolan": {"name": "CAPTAIN ROLAN OF THE WATCH", "spot": "gate", "look": [Color(0.3, 0.35, 0.45), Color(0.4, 0.8, 1.0)],
		"greet": ["My hand is on my hilt, tyrant. Walk on. Walk ON.",
			"There's trouble past the walls. You could do the city a favor. Not that you owe us one.",
			"The Watch salutes you, my lord. Point us at it, and we march with you."],
		"service": "bounty"},
	"greta": {"name": "GRETA OF THE RUSTED COG", "spot": "cog", "look": [Color(0.55, 0.3, 0.25), Color(0.7, 0.5, 0.3)],
		"greet": ["W-what'll it be? First one's free. All of them are free. Please don't break anything.",
			"Ale's hot, the cog-fire's hotter. You pay like anyone else now.",
			"Saint's at the bar! Drinks are on the house, and the house is honored."],
		"service": "drink"},
	"liore": {"name": "LIORE THE TINKER", "spot": "clock", "look": [Color(0.4, 0.3, 0.5), Color(0.3, 0.9, 0.8)],
		"greet": ["The clock... the clock skips a beat when you stand near it. Please stand further away.",
			"Every day the aether runs stronger through Vael. Steel learns. Swords become something else.",
			"Since you started walking the streets, the conduits glow brighter. I've stopped trying to explain it."],
		"service": "tune"},
	"oswin": {"name": "OSWIN THE MINSTREL", "spot": "plaza", "look": [Color(0.6, 0.2, 0.3), Color(0.9, 0.7, 0.2)],
		"greet": ["(He stops playing mid-note.) I- I sing only of your greatness, my lord. Only of that.",
			"New song. About a man in white who sits at the same table every night. Want to hear it?",
			"I wrote a hymn for you. The children already know the words. Shall I play it?"],
		"service": "song"},
	"ansel": {"name": "WIDOW ANSEL", "spot": "graves", "look": [Color(0.15, 0.15, 0.18), Color(0.3, 0.3, 0.35)],
		"greet": ["My husband died on your bridge, King. Leave me with the dead. They don't fear you. I do.",
			"There's a grave here with no body. Name says WREN. Do you know who put it here?",
			"You came to pray. For him. My husband would have liked you, the way you are now."],
		"service": "grave"},
	"toms": {"name": "TOMS, KEEPER OF THE HOLLOW FLAGON", "spot": "flagon", "look": [Color(0.3, 0.2, 0.15), Color(0.6, 0.45, 0.3)],
		"greet": ["We don't open till dusk, my lord. ...For you, the door is open. It's always been open for you.",
			"He comes every night, the man in white. Orders what you'd order. Sits where you'd sit.",
			"Two chairs at the corner table, saint. Been that way for years. I finally know why."],
		"service": "wait"},
}

# What each kind of service says it does (shown as the choice label).
const SERVICES := {
	"bread": "Buy warm bread (heal 60) · 6 DREAD",
	"weapons": "Browse the forge",
	"bless": "Receive a blessing (+40 Will tonight) · 25 DREAD",
	"give": "Give the child 10 DREAD",
	"bounty": "Ask where the trouble is",
	"drink": "Buy a round (+25 Will tonight) · 15 DREAD",
	"tune": "Tune your weapon with aether (+20% weapon damage) · 35 DREAD",
	"song": "Listen to the song",
	"grave": "Kneel at the grave marked WREN",
	"wait": "Sit at the corner table and wait for dusk",
}

const INTIMIDATE := "Demand tribute (+20 DREAD. They will remember.)"
