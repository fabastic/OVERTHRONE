extends RefCounted
## THE LAMPLIGHTER: a smaller story that runs alongside the King's, one step a day in Vael.
##
## Edda lights Vael's aether lamps, and has done for fifty years. Every night now, lamps go dark:
## their hearts are pried out by the CROWNLESS, a cult in empty-crown masks who carry the aether
## somewhere north, to "feed the Voice". Each day she asks for your help. Each step ends in a fight
## you can WIN, and each win gives a BOON (GameState.BOONS) that helps you against the challengers
## at night. On the last day there is no fight: just a lamp, and something she has always known.
##
## Also here: the SECRETS of Vael (easter eggs about the King's true story, one at each lair and
## more in the city), the CHRONICLE OF VAEL (lore pages), the town crier's news, and ambush shouts.

# --- The Lamplighter's story, one step per day -------------------------------------------------
# where: local overworld position. foes: [[kind, count], ...]. elite: name of the leader ("" = none).
const QUEST := [
	{"title": "THE DARK LANE", "where": Vector3(-24, 0, 1.5), "where_name": "WEAVER'S LANE, WEST QUARTER",
		"ask": "Three lamps on Weaver's Lane went dark last night. Not burned out, mind. TAKEN. The hearts pried out of them like teeth.\n\nI'm too old to chase thieves. You're not. And you're... well. They'll run from you, won't they?",
		"foes": [["cultist", 3]], "elite": "",
		"won": "The last thief's mask cracks on the cobbles: white porcelain, an empty crown scratched into the brow.\n\nEdda turns it over in her hands. \"Crownless,\" she says. \"I thought they were a story for children.\"",
		"boon": "lamp"},
	{"title": "THE MILLER'S CELLAR", "where": Vector3(-52, 0, -12), "where_name": "THE OLD MILL, WEST OF THE WALLS",
		"ask": "Rolan's men followed the lamp-hearts out the west gate. A cart, a cellar, a light that hums. He won't go himself. Says it's not Watch business.\n\nIt's my business. I'll make it yours, if you'll let me.",
		"foes": [["cultist", 4]], "elite": "BROTHER HOLLOW",
		"won": "Brother Hollow's ledger, in a tidy hand:\n\"HEARTS DELIVERED: 31. All of it to the North, for the Voice, which speaks from the crown of the King.\"\n\nCaptain Rolan reads it twice, swears, and hands you his own whistle. \"Blow it and the Watch comes. All of it. I mean that.\"",
		"boon": "whistle"},
	{"title": "WHAT PIP SAW", "where": Vector3(22, 0, 18), "where_name": "BEHIND THE WATCH STABLES",
		"ask": "Pip came to me in the night. Says a man in a crown-mask pays the stable boys in aether to look the other way. Pip won't say which ones.\n\nPip's frightened. Pip's also nine, and braver than the Watch. Go before the child does something stupid.",
		"foes": [["cultist", 3]], "elite": "THE MASKED CARTER",
		"won": "The Carter's cart is full of lamp-hearts, wrapped in straw like eggs. Pip counts them, all of them, out loud.\n\nThen Pip presses something into your hand: a brass button, polished thin. \"It's lucky. It was my da's. You need it more.\"",
		"boon": "button"},
	{"title": "THE VIGIL", "where": Vector3(4, 0, -15), "where_name": "THE CATHEDRAL STEPS",
		"ask": "Sister Ivy keeps a vigil candle on the cathedral steps. It's burned since the Dawnbringer's crowning, and the Crownless mean to put it out. Symbol of something, I suppose.\n\nShe won't leave it. Of course she won't.",
		"foes": [["cultist", 5]], "elite": "SISTER NULL",
		"won": "Sister Null was one of Ivy's novices once. Ivy kneels by her a long while.\n\nThen she gives you a stub of the vigil candle. \"It has never gone out. Take it to the table tonight. Let it watch your hands for you.\"",
		"boon": "candle"},
	{"title": "THE CLOCK'S HEART", "where": Vector3(-42, 0, -56), "where_name": "THE GEARWRIGHT'S CAMP, NORTHWEST",
		"ask": "Liore's in pieces. The clocktower's heart is gone, the big one, the one that keeps the hours. Without it the clock just... stops. Liore says the city stops with it, in ways we don't notice yet.\n\nThere's a camp in the northwest. Smoke and ticking.",
		"foes": [["cultist", 4], ["automaton", 2]], "elite": "THE GEARWRIGHT",
		"won": "The Gearwright built the masks. Built them to see through: aether lenses, ground thin. With one on, the Voice is louder.\n\nLiore smashes all but one, and grinds it clear. \"Here. Look through this and nothing hides its tricks for long.\"",
		"boon": "lens"},
	{"title": "THE UNDERCROFT", "where": Vector3(22, 0, -62), "where_name": "BENEATH THE DAWNSPIRE ROAD",
		"ask": "This is where they take them. All the hearts, every one, down under the Dawnspire road. Their priest is there. Vess, they call her.\n\nI should tell you something. I used to know the man who built this city's lamps. He'd have gone himself. ...Go carefully, my lord.",
		"foes": [["cultist", 5], ["automaton", 2]], "elite": "THE CROWN-PRIEST VESS",
		"won": "Vess laughs as she falls. \"You think you stopped us? It doesn't need the hearts. It needs HIM. And he's opening the door himself, one memory at a time.\"\n\nIn her hands, still warm, the last stolen lamp-heart. It beats like something alive.",
		"boon": "heart"},
	{"title": "THE LAST LAMP", "where": Vector3(-6.5, 0, 10), "where_name": "THE FOUNTAIN PLAZA",
		"ask": "No more fighting. Not today. Come and help an old woman light a lamp.",
		"foes": [], "elite": "",
		"won": "You set the last heart into the plaza lamp and it catches, gold and steady.\n\nEdda watches you, not the lamp. \"You lit the first one, you know. Fifty years ago, before the crown. You said every street deserved a morning.\n\n\"I always knew it was you, Dawnbringer. I just wanted you to remember it yourself.\"",
		"boon": "dawnlamp"},
]

const EDDA := {"name": "EDDA, THE LAMPLIGHTER", "look": [Color(0.3, 0.28, 0.4), Color(1.0, 0.8, 0.35)], "spot": Vector3(-6.5, 0, 10),
	"greet": ["You're the King. Yes, yes, I know. I'm too old to be frightened of anything but the dark.",
		"Good morning, my lord. The lamps stayed lit on the streets you walked last night. Funny, that.",
		"There he is. Sit with me a moment. I've lit ten thousand lamps and none of them were as bright as you look today."],
	"done": "That's today's work done. Go on, live a little. Dusk comes for all of us."}

# --- Secrets of Vael: the King's story, hidden where it happened -------------------------------
# need: memories restored before the secret says everything (0 = always). crowns: first-find reward.
const SECRETS := [
	{"id": "wren_sword", "pos": Vector3(68, 0, -43), "title": "A SWORD IN A STUMP", "need": 1,
		"locked": "A plain sword, driven deep into a burned stump. It will not move. Not for you. Not yet.",
		"text": "A plain sword, driven deep into a burned stump. WREN is scratched into the crossguard, badly, by a child.\n\nYour father's. You borrowed it to go and be a hero, and never gave it back.\n\nThis time it comes out of the wood like it was waiting for you.",
		"weapon": "borrowed"},
	{"id": "corvin_shield", "pos": Vector3(-6, 0, 63), "title": "A SHIELD BY THE BRIDGE", "need": 2,
		"locked": "A blue kite shield, split down the middle, half sunk in the mud by the bridge. Words are painted on the back, too faded to read.",
		"text": "A blue kite shield, split down the middle. On the back, in old paint:\n\"I WILL HOLD THE BRIDGE TO THE LAST MAN. — C.\"\n\nAnd under it, scratched with a knife point:\n\"I held them home instead.\""},
	{"id": "lion_laurel", "pos": Vector3(-62, 0, -36), "title": "A LAUREL IN THE SAND", "need": 3,
		"locked": "A dead laurel crown in the pit sand, and a torn ticket.",
		"text": "A dead laurel crown in the pit sand, and a torn ticket:\n\"TONIGHT! THE LION versus ANYONE!\"\n\nOn the back, in your hand, a name you wrote so you would not forget it. You forgot it anyway."},
	{"id": "ashe_ledger", "pos": Vector3(58, 0, 37), "title": "A LEDGER AT THE PYRE", "need": 4,
		"locked": "A cathedral ledger, scorched, pages fused at the edges.",
		"text": "A cathedral ledger: a list of names, each with a date and the word PURIFIED.\n\nThe last entry is in Brother Ashe's hand. It is your own name. He crossed it out, and could not bring himself to write the word after it."},
	{"id": "alder_mask", "pos": Vector3(-58, 0, 41), "title": "A SAINT'S MASK", "need": 5,
		"locked": "A porcelain mask, smiling, propped against a column. Something is written inside it.",
		"text": "A porcelain saint's mask, smiling serenely. The pilgrims never saw Alder without it.\n\nInside, in small cramped letters, over and over:\n\"IT IS SO HEAVY TO SMILE. IT IS SO HEAVY TO SMILE.\""},
	{"id": "empty_throne", "pos": Vector3(6, 0, -73), "title": "A THRONE OF BLACK GLASS", "need": 6,
		"locked": "A throne of black glass at the foot of the Dawnspire, empty. The seat is worn into the shape of a crown. You do not want to touch it.",
		"text": "A throne of black glass at the foot of the Dawnspire, empty. The seat is worn into the shape of a crown.\n\nYou touch it. Very faintly, from somewhere above your own head, a voice that is not yours:\n\"Almost. Thank you. Almost.\""},
	{"id": "statue", "pos": Vector3(8, 0, -8.5), "title": "THE DAWNBRINGER'S STATUE", "need": 0,
		"locked": "", "text": "A statue of the Dawnbringer, sword raised. Someone chiselled the face away years ago.\n\nIn this light, the stone that is left has the shape of your jaw."},
	{"id": "pip_drawing", "pos": Vector3(25.6, 0, 10.5), "title": "CHALK ON THE WALL", "need": 0,
		"locked": "", "text": "A child's chalk drawing: two men holding hands. One is coloured in white, one in black. Both have crowns.\n\nUnderneath: \"THE KING AND HIS FRIEND. THEY ARE THE SAME.\" Pip spells better than you'd think."},
	{"id": "flagon_table", "pos": Vector3(21.6, 0, -13), "title": "INITIALS IN THE WOOD", "need": 0,
		"locked": "", "text": "Carved into a beam of the Hollow Flagon, old and smoothed by hands:\n\"W. & W. — SAME TABLE, EVERY NIGHT.\""},
	{"id": "bell", "pos": Vector3(7.6, 0, -24), "title": "THE CATHEDRAL BELL", "need": 0,
		"locked": "", "text": "A cracked bell, too heavy to hang again. Cast into its lip:\n\"RUNG FOR THE CROWNING OF THE DAWNBRINGER. LET IT NEVER RING FOR A WORSE DAY.\"\n\nIt never rang again."},
	{"id": "thirteen", "pos": Vector3(-21, 0, -22), "title": "THE THIRTEENTH HOUR", "need": 0,
		"locked": "", "text": "Up close, the clock has thirteen hours. The thirteenth is painted over, but you can still read it: DUSK.\n\nLiore swears it was not there when the clock was built."},
	{"id": "river_ring", "pos": Vector3(14, 0, 66), "title": "A HOLLOW IN THE SILT", "need": 0,
		"locked": "", "text": "At the river's edge, a perfect ring-shaped hollow pressed into the silt, as if a ring lay here for years.\n\nSomeone has already picked it up. Someone in white, the ferrywoman says."},
]

# --- The Chronicle of Vael: pages scattered through the city and the wilds ----------------------
const PAGES := [
	{"pos": Vector3(-3, 0, -17), "text": "I. Before Vael there was only the Ford: a crossing, a mill, a well. The Ford had no king and wanted none."},
	{"pos": Vector3(-34, 0, 34), "text": "II. In the year of the Falling Star, a stone came down burning in the north hills. It did not cool. Those who stood near it heard it speak."},
	{"pos": Vector3(33, 0, -33), "text": "III. Aurex the smith beat the star into a crown. He wore it once, to see how it fit. He never took it off again. He was the first Hollow King."},
	{"pos": Vector3(-46, 0, 2), "text": "IV. Aurex ruled for ninety years and did not age. The crown aged instead: it grew heavier, and it learned the names of everyone he hated."},
	{"pos": Vector3(46, 0, 22), "text": "V. A boy from the Ashen Vale, a knight without a name, a champion, a monk, a saint. The chronicle lists them as five men. The chronicle is wrong."},
	{"pos": Vector3(-20, 0, -52), "text": "VI. The Dawnbringer climbed the Spire alone. The bards say he killed Aurex with a single blow. The bards were not there. Nobody knows how long it took."},
	{"pos": Vector3(30, 0, 58), "text": "VII. When the Dawnbringer came down he was wearing the crown. \"Only until the war is over,\" he said. Every Hollow King says that."},
	{"pos": Vector3(-70, 0, 60), "text": "VIII. Aether came out of the ground the year the Dawnbringer was crowned, as if the earth were glad. Edda the lamplighter set the first heart in the first lamp."},
	{"pos": Vector3(75, 0, -10), "text": "IX. The crown does not want a king. It wants a door. Every king it wears is a little more open than the last."},
	{"pos": Vector3(-8, 0, -88), "text": "X. (The last page is blank except for one line, in fresh ink, in your handwriting:) \"Don't let it finish.\""},
]

# --- The town crier, at noon and at other hours -------------------------------------------------
const CRIER := [
	["HEAR YE! The King walks the streets! Keep your doors shut and your children closer!", "HEAR YE! Raiders seen past the east gate! The Watch advises: stay home!", "HEAR YE! Lamps out on Weaver's Lane! The Lamplighter asks for help! (Nobody is helping.)"],
	["HEAR YE! The burned farm is quiet! Who did it? Nobody will say!", "HEAR YE! A man in white was seen in two places at once! The Watch says that's impossible!", "HEAR YE! The bridge is open again! Mind the Warden!"],
	["HEAR YE! Tickets for the Sunfield Pit! ...Cancelled! By order of nobody!", "HEAR YE! The King paid for his bread! Marta has fainted!", "HEAR YE! Masked men seen at the stables! The stable boys deny everything, suspiciously!"],
	["HEAR YE! A vigil at the cathedral tonight! Bring a candle! Bring a sword!", "HEAR YE! The Inquisitor's pyre burns cold! Some say good riddance! Quietly!", "HEAR YE! The King smiled! Witnesses disagree!"],
	["HEAR YE! The clocktower has stopped! What hour is it? Nobody knows!", "HEAR YE! The Gilded Prophet preaches no more! The crowd has moved on to the fountain!", "HEAR YE! Pilgrims arrive to see the King! The King is... not what they expected!"],
	["HEAR YE! A black glass knight walks the Dawnspire road! Do not walk the Dawnspire road!", "HEAR YE! The Lamplighter's lamps burn brighter than ever! She thanks no one in particular!", "HEAR YE! Tonight, they say, is the last game at the Flagon!"],
	["HEAR YE! The last day! Of what, nobody's sure! Everyone can feel it!", "HEAR YE! The man in white has been seen nowhere today! Everywhere is very quiet!", "HEAR YE! Bless the King! ...Yes, THAT King! Bless him anyway!"],
]

const AMBUSH_SHOUTS := [
	"THERE HE IS! THE TYRANT!", "For the Voice!", "The crown wants him whole!", "Get the King!", "He's alone! NOW!",
]
