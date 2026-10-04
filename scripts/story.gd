extends RefCounted
## The Hollow King's story, laid out as the board.
## The board is the map of his life. Each region is a chapter; each chapter ends with a CHALLENGER.
## They look like ordinary heroes come to dethrone him, with ordinary names. They are not:
## each one is a self he locked away. The player only learns this slowly, one memory at a time.
## (Internally the challenger tile is still called "demon".)
##
## Tile types:  story · event (choice) · treasure · altar (classes) · demon

const CHAPTERS := [
	{
		"region": "THE ASHEN VILLAGE",
		"arrive": "A boy blocks the road, sword raised. He looks familiar, somehow.",
		"color": Color(0.55, 0.3, 0.2),
		"prop": "village",
		"tiles": [
			{"type": "story", "text": "I know this road. The mud remembers my boots, even if I do not."},
			{"type": "event", "title": "THE WELL OF NAMES", "text": "An old well. Names are carved around its lip, hundreds of them. One has been scratched out so hard the stone is gouged.",
				"options": [["Read the names (+1 memory fragment, +6 Crowns)", "fragment|crowns:6"], ["Drop a coin in (+40 Dread next fight)", "dread:40"]]},
			{"type": "treasure", "text": "A child's toy chest, half buried in ash.", "effect": "crowns:12"},
			{"type": "story", "text": "Smoke on the horizon. I was not here when it burned. I was off somewhere, proving I was brave."},
			{"type": "demon"},
		],
		"memory_title": "THE BOY WITH THE BORROWED SWORD",
		"memory": "Wren. That was the name your mother called you.\n\nYou were a farm boy who swore to protect this village with a sword you had borrowed from your father.\n\nYou went to the capital to win glory. While you were gone, raiders came. You returned to ash.\n\nThe squire you fought was you: the boy who never forgave you for leaving.",
		"relic": "sword",
	},
	{
		"region": "OATHKEEP",
		"arrive": "A knight in faded colors. Colors I used to wear.",
		"color": Color(0.3, 0.38, 0.6),
		"prop": "keep",
		"tiles": [
			{"type": "story", "text": "Banners of a king I once served. The thread is rotten. So was he."},
			{"type": "altar", "text": "A CLASS ALTAR. Its fire still answers an old knight's prayers."},
			{"type": "event", "title": "THE DESERTER'S CAMP", "text": "Cold ashes and a ring of helmets. My men waited for me here, once, while I decided whether to obey.",
				"options": [["Wear a helmet (a free skill from your classes)", "skill"], ["Burn the banner (+14 Crowns, but the next demon stands firmer)", "crowns:14|curse:0.08"]]},
			{"type": "story", "text": "They called me traitor. I called it mercy. Both of us were right."},
			{"type": "demon"},
		],
		"memory_title": "THE OATH YOU BROKE",
		"memory": "Ser Corvin. The name they gave you when they knighted you.\n\nYou were knighted on these stones. When your king ordered your company to hold a bridge to the last man, you led them home instead.\n\nThey lived. You were branded a traitor and stripped of your name.\n\nCorvin is the part of you that still believes the oath mattered more.",
		"relic": "ring",
	},
	{
		"region": "THE SUNFIELD",
		"arrive": "The crowd roars a name. For a moment, I thought it was mine.",
		"color": Color(0.75, 0.6, 0.25),
		"prop": "arena",
		"tiles": [
			{"type": "story", "text": "Sand and roses. The crowd's roar is still trapped in these stands, like heat in a stone."},
			{"type": "treasure", "text": "A champion's purse, never collected.", "effect": "crowns:20|skill"},
			{"type": "event", "title": "THE EMPTY BOX SEAT", "text": "The best seat in the arena. Whoever sat here decided who lived. A purple cushion, still warm.",
				"options": [["Sit (+1 memory fragment, Reforge a skill)", "fragment|rank"], ["Tear it down (+18 Crowns)", "crowns:18"]]},
			{"type": "story", "text": "I learned to love the roar more than the faces making it."},
			{"type": "demon"},
		],
		"memory_title": "THE ROAR",
		"memory": "The Lion. You took that name in the sand and let it eat the old ones.\n\nNameless, you fought for coin in the Sunfield. You never lost. They sang your name, a new one, and you let it replace the old.\n\nYou stopped seeing the men you beat. Only the crowd.\n\nThe Lion is the hunger for applause you never fed again.",
		"relic": "laurel",
	},
	{
		"region": "THE CATHEDRAL OF VOWS",
		"arrive": "A paladin waits, holding the same prayer book I once held.",
		"color": Color(0.7, 0.72, 0.8),
		"prop": "cathedral",
		"tiles": [
			{"type": "story", "text": "Incense and cold marble. I came here to be forgiven, and stayed to forgive no one."},
			{"type": "altar", "text": "A CLASS ALTAR, burning with a pale and pious flame."},
			{"type": "event", "title": "THE CONFESSIONAL", "text": "A curtained booth. Someone is waiting on the other side, breathing slowly.",
				"options": [["Confess (+2 memory fragments)", "fragment|fragment"], ["Hear their confession instead (+60 Dread next fight)", "dread:60"]]},
			{"type": "story", "text": "Every sinner I judged had my face."},
			{"type": "demon"},
		],
		"memory_title": "THE VOW",
		"memory": "Brother Ashe. Your name in the Cathedral's ledger, in your own hand.\n\nYou took holy vows to atone for the village, the bridge, the arena. You became a Paladin, and you were merciless.\n\nYou burned heretics so no one would look closely at you.\n\nAshe is the judgment you aimed at everyone but yourself.",
		"relic": "censer",
	},
	{
		"region": "PILGRIM HEIGHTS",
		"arrive": "A saint, smiling at me as if we have met. He moves the way I move.",
		"color": Color(0.6, 0.75, 0.85),
		"prop": "peaks",
		"tiles": [
			{"type": "story", "text": "They climbed this mountain to touch my robes. I let them."},
			{"type": "treasure", "text": "Offerings left at a shrine with your face on it.", "effect": "crowns:30|rank"},
			{"type": "event", "title": "THE GOLDEN MASK", "text": "A saint's death mask, beaten from gold. The inside is black with rot.",
				"options": [["Wear it (a free skill and +20 Crowns, but the next demon stands firmer)", "skill|crowns:20|curse:0.1"], ["Shatter it (+1 memory fragment, +12 Crowns)", "fragment|crowns:12"]]},
			{"type": "story", "text": "That is when the crown first whispered. It said: they already worship you. Why not rule?"},
			{"type": "demon"},
		],
		"memory_title": "THE ROT UNDER GOLD",
		"memory": "Saint Alder. They carved it over a thousand doorways.\n\nThey called you a saint. Pilgrims came from every kingdom. You smiled and blessed them, and inside you something curdled.\n\nYou wanted it all to stop. You wanted it all to obey.\n\nAlder is the mask you wore so well that you forgot your own face.",
		"relic": "ashes",
	},
	{
		"region": "THE DAWNSPIRE",
		"arrive": "He has my eyes.",
		"color": Color(1.0, 0.8, 0.45),
		"prop": "spire",
		"tiles": [
			{"type": "story", "text": "The tower where the old tyrant died. Where I killed him. Where I picked up his crown."},
			{"type": "altar", "text": "THE LAST ALTAR. Every flame you ever prayed to, burning at once."},
			{"type": "event", "title": "THE TYRANT'S THRONE", "text": "An empty throne, identical to yours. The cushion still holds the shape of someone.",
				"options": [["Sit (+40 Crowns)", "crowns:40"], ["Kneel before it (+2 memory fragments, a free skill)", "fragment|fragment|skill"]]},
			{"type": "story", "text": "One part of me never stopped believing the morning would come. I locked him away the highest."},
			{"type": "demon"},
		],
		"memory_title": "THE HOLLOW KING",
		"memory": "The Dawnbringer. The last name the people gave you, before they called you King.\n\nYou climbed the Dawnspire to end the tyrant's war. You won. And when you lifted his crown, you put it on.\n\nYou became what you killed: the Hollow King, ruling an empty hall inside your own mind.\n\nThe Dawnbringer was never your enemy. He was the hope you buried. Now he is part of you again.",
		"relic": "dawn",
	},
]

const ENDING := "Wren. Corvin. The Lion. Ashe. Alder. The Dawnbringer.\nEvery name you ever wore came to take your throne, and every one was you.\n\nNot slain: remembered. They kneel, and stand, and walk into you.\n\nFor the first time in a long time, the Hollow King is not hollow.\n\nAnd then the crown on your head speaks, in a voice that is not yours:\n\n\"Thank you for opening the door.\"\n\nFar beyond the board, something vast opens its eye."


static func tiles_flat() -> Array:
	var out: Array = []
	for c in CHAPTERS.size():
		var tiles: Array = CHAPTERS[c]["tiles"]
		for i in tiles.size():
			out.append({"chapter": c, "index": i, "data": tiles[i]})
	return out
