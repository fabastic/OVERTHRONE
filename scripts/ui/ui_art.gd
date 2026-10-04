extends RefCounted
## Pixel-art helpers for the UI: a 5x7 bitmap font, hand-drawn 12x12 icons, diamond node
## frames and ornate 9-slice panels. Everything is generated once in code and cached.

const ICON_SIZE := 12
const PALETTE := {
	"o": Color("1a0a10"),
	"r": Color("c03a28"),
	"y": Color("f29a2e"),
	"w": Color("ffe6a6"),
	"b": Color("2f6cff"),
	"c": Color("8fd8ff"),
	"d": Color("1a2a7a"),
	"e": Color("ffffff"),
}

# 12x12 icons. Missing characters at the end of a row are transparent.
const ICONS := {
	"fireball": [
		".....y......",
		"....yy..y...",
		"...yyy.yy...",
		"..yywyyyy...",
		"..ywwwyyr...",
		".yywwwwyrr..",
		".yywwwwyyr..",
		".ryywwyyrr..",
		"..rryyyrr...",
		"...rrrrr....",
		"....rrr.....",
	],
	"slam": [
		"...yyyyy....",
		"..ywwwwwy...",
		"..ywyywyy...",
		"..yyyyyyy...",
		"..ryyyyyr...",
		"...rrrrr....",
		".....r......",
		"y...r.r...y.",
		".y.r...r.y..",
		"rrrrrrrrrrrr",
		"r.r..r..r.r.",
	],
	"spikes": [
		".....w......",
		".....w......",
		"....wyw.....",
		".w..wyw..w..",
		".w..wyw..w..",
		"wyw.yyy.wyw.",
		"wyw.yry.wyw.",
		"yyy.yry.yyy.",
		"yry.yry.yry.",
		"rrrrrrrrrrrr",
		".r.r.r.r.r..",
	],
	"lance": [
		"..........ww",
		".........wwy",
		"........wyy.",
		".......yyy..",
		"......yy....",
		".....yy.....",
		"....yy......",
		"..wyy.......",
		"..ry........",
		".rrw........",
		"rr..........",
		"r...........",
	],
	"chains": [
		"............",
		"..yyyy......",
		".y....y.....",
		".y..rrrrr...",
		".y.r..y..r..",
		"..yyyy...r..",
		"....r...r...",
		"....r..yyyy.",
		".....rry...y",
		".......y...y",
		"........yyy.",
	],
	"lightning": [
		"......wy....",
		".....wy.....",
		"....wy......",
		"...wy.......",
		"..wyyyyy....",
		"......wy....",
		".....wy.....",
		"....wyyyy...",
		".......yr...",
		"......yr....",
		".....yr.....",
		"....r.......",
	],
	"well": [
		"...rrrrrr...",
		"..r......r..",
		".r..yyyy..r.",
		"r..y....y..r",
		"r.y..ww..y.r",
		"r.y.w.ow.y.r",
		"r.y.w.oo.y.r",
		"r..y..w..y.r",
		"r...yy..y..r",
		".r.....y..r.",
		"..rr.....r..",
		"....rrrr....",
	],
	"eclipse": [
		".....y......",
		".y...y...y..",
		"..y.rrr.y...",
		"...rooor....",
		"yyroooooryy.",
		"...roooor...",
		"..y.rrr.y...",
		".y...y...y..",
		".....y......",
	],
	"vigor": [
		"..y......y..",
		"..yy.yy.yy..",
		"..yyyyyyyy..",
		"..yrrrrrry..",
		"..yr.ww.ry..",
		"..yr.ww.ry..",
		"yyyyyyyyyyyy",
		"yrrrrrrrrrry",
		"yy........yy",
		"yy........yy",
		"rr........rr",
	],
	"wrath": [
		"y..........y",
		"wy........yw",
		".wy......yw.",
		"..wy....yw..",
		"...wy..yw...",
		"....wyyw....",
		"....ywwy....",
		"...yr..ry...",
		"..rr....rr..",
		".rr......rr.",
		"rr........rr",
	],
	"presence": [
		"............",
		"y....y....y.",
		"yy..yyy..yy.",
		"yyy.yyy.yyy.",
		"yyyyyyyyyyy.",
		"yrywyrywyry.",
		"yyyyyyyyyyy.",
		"rrrrrrrrrrr.",
		"............",
		"..r..r..r...",
		"...r.r.r....",
	],
	"haste": [
		".yyyyyyyyy..",
		"..r.....r...",
		"..rw...wr...",
		"...rwwwr....",
		"....rwr.....",
		".....r......",
		"....r.r.....",
		"...r.w.r....",
		"..r.www.r...",
		"..rwwwwwr...",
		".yyyyyyyyy..",
	],
	"unreadable": [
		"............",
		"..yyyyyyyy..",
		".yyyyyyyyyy.",
		".yoo.yy.ooy.",
		".yooyyyyooy.",
		".yyyyyyyyyy.",
		".yyyyrryyyy.",
		"..yyy..yyy..",
		"..yr.rr.ry..",
		"...yyyyyy...",
		"....yyyy....",
	],
	"fog": [
		"............",
		"....rrr.....",
		"..rryyyrr...",
		".ryyyyyyyr..",
		"ryywwwwwyyr.",
		"ryyyyyyyyyr.",
		".rrrrrrrrr..",
		"............",
		"..y.y.y.y...",
		".y.y.y.y....",
		"..y.y.y.y...",
	],
	"harvest": [
		".....w......",
		"....wy......",
		"....yy......",
		"...yyyy.....",
		"..yywyyy....",
		"..ywyyyyr...",
		".yywyyyyr...",
		".yyyyyyrr...",
		".ryyyyyr....",
		"..rrrrr.....",
	],
	"generous": [
		".....y......",
		"....ywy.....",
		"....ywy.....",
		".....y......",
		"....www.....",
		"....wyw.....",
		"....wyw.....",
		"....wyw.....",
		"...rrrrr....",
		"..rrrrrrr...",
		".yyyyyyyyy..",
	],
	"fated": [
		".....w......",
		".....w......",
		"....wyw.....",
		"yyyywywyyyy.",
		".yyyyyyyyy..",
		"..yyyyyyy...",
		"..yyy.yyy...",
		".yy.....yy..",
		".y.......y..",
	],
	"volley": [
		".......yy...",
		"......ywwy..",
		"..yy..ywwy..",
		".ywwy..yy...",
		".ywwy.......",
		"..yy...yy...",
		"r.....ywwy..",
		".r....ywwy..",
		"..r....yy...",
		"...r........",
		"....rr......",
		"......rr....",
	],
	"pillar": [
		".....yy.....",
		"....ywwy....",
		"....ywwy....",
		"...yywwyy...",
		"...ywwwwy...",
		"...ywwwwy...",
		"...yywwyy...",
		"...ryyyyr...",
		"..rryyyyrr..",
		".rrrryyrrrr.",
		"rrrrrrrrrrrr",
	],
	"meteor": [
		"w...........",
		".ww.........",
		"..wyy.......",
		"...yyy......",
		"....yyyy....",
		".....yrrr...",
		"....yrrrrr..",
		"....yrrorr..",
		"....yrrrrr..",
		".....rrrr...",
		"............",
		"y.r.y..r..y.",
	],
	"wall": [
		"............",
		"w.w.w.w.w.w.",
		"wwwwwwwwwww.",
		".y.y.y.y.y..",
		".y.y.y.y.y..",
		".y.y.y.y.y..",
		".y.y.y.y.y..",
		".y.y.y.y.y..",
		"wwwwwwwwwww.",
		"rrrrrrrrrrr.",
	],
	"tide": [
		"............",
		"...yyyy.....",
		"..y....y....",
		".y......y...",
		"y........y..",
		"...rrrr.....",
		"..r....r....",
		".r......r...",
		"r........r..",
		"............",
		"wwwwwwwwwwww",
	],
	"bloom": [
		".....w......",
		"..w..w..w...",
		"...w.w.w....",
		"....www.....",
		"wwwwwywwwww.",
		"....www.....",
		"...w.w.w....",
		"..w..w..w...",
		".....w......",
	],
	"timerend": [
		"...yyyyy....",
		"..y.....y...",
		".y...w...y..",
		"y....w....y.",
		"y....w....y.",
		"y....wwww.y.",
		"y.........y.",
		".y.......y..",
		"..y.....y...",
		"...yyyyy....",
	],
	"doom": [
		"....rrrr....",
		"..rr....rr..",
		".r...yy...r.",
		".r..y..y..r.",
		"r..y.ww.y..r",
		"r..y.ww.y..r",
		".r..y..y..r.",
		".r...yy...r.",
		"..rr....rr..",
		"....rrrr....",
	],
	"rain": [
		"..r.....r...",
		"..r..r..r...",
		".rr..r.rr...",
		".rr.rr.rr...",
		"....rr......",
		"..r.....r...",
		".rr..r..r...",
		".rr.rr.rr...",
		"....rr......",
		"yyyyyyyyyyy.",
	],
	"maw": [
		"....y.......",
		"....yy......",
		".....yo.....",
		"....yoo.....",
		"...yooy.....",
		"....yoo.....",
		".....yooy...",
		"....yooy....",
		"...yooy.....",
		"....yy......",
		"yyyyyyyyyyy.",
	],
	"hands": [
		"..y.y.y.....",
		"..y.y.y.y...",
		"..y.y.y.y...",
		"..yyyyyyy...",
		"y.yyyyyyy...",
		"yyyyywyyy...",
		".yyyyyyyy...",
		"..yyyyyy....",
		"...yyyy.....",
		"...rrrr.....",
	],
	"hex": [
		"...yyyyy....",
		"..yyyyyyy...",
		".yyoyyyoyy..",
		".yooyyyooy..",
		".yyyyyyyyy..",
		"..yyyoyyy...",
		"...y.y.y....",
		"...yyyyy....",
		"r.........r.",
		".r..r.r..r..",
	],
	"siphon": [
		"y...........",
		".y..........",
		"..y.........",
		"...y.....r..",
		"....y...rr..",
		".....y.rrr..",
		"......rrwr..",
		".....rrrwrr.",
		".....rrrrrr.",
		"......rrrr..",
	],
	"ghouls": [
		"...wwwww....",
		"..wwwwwww...",
		".wwowwwoww..",
		".wwowwwoww..",
		".wwwwwwwww..",
		"..wwwowww...",
		"..w.w.w.w...",
		"...wwwww....",
		"..r.....r...",
		".r.r...r.r..",
	],
	"talons": [
		"y...y...y...",
		"y...y...y...",
		"wy..wy..wy..",
		".wy..wy..wy.",
		"..yy..yy..y.",
		"...yyyyyyyy.",
		"...rrrrrrr..",
		"....rrrrr...",
	],
	"scale": [
		".yyyyyyyyy..",
		".yrrrrrrry..",
		".yrwwrrrry..",
		".yrwrrrrry..",
		".yrrrrrrry..",
		"..yrrrrry...",
		"..yrrrrry...",
		"...yrrry....",
		"....yry.....",
		".....y......",
	],
	"riposte": [
		"w.........w.",
		".w...y...w..",
		"..w..y..w...",
		"...wyyyw....",
		".yyyywyyyy..",
		"...wyyyw....",
		"..w..y..w...",
		".w...y...w..",
		"r.........r.",
	],
	"colossus": [
		"....yyy.....",
		"....ywy.....",
		"..yyyyyyy...",
		".yy.yyy.yy..",
		".y..yyy..y..",
		"....yyy.....",
		"...yy.yy....",
		"...y...y....",
		"..rr...rr...",
	],
	"might": [
		"..yyyyyy....",
		".ywwywwyy...",
		".yyyyyyyy...",
		".ywwywwyy...",
		".yyyyyyyy...",
		"..yyyyyyy...",
		"...yyyyy....",
		"...rrrrr....",
		"...rrrrr....",
	],
	"grudge": [
		"..y.....y...",
		".yyy...yyy..",
		"yrrry.yrrry.",
		"yrrrrrrrrry.",
		"yrrrrwrrrry.",
		".yrrrrrrry..",
		"..yrrrrry...",
		"...yrrry....",
		"....yry.....",
		".....y......",
	],
	"fate": [
		".....y......",
		".....y......",
		"....ywy.....",
		"..yywwwyy...",
		"yywwwwwwwyy.",
		"..yywwwyy...",
		"....ywy.....",
		".....y......",
		".....y......",
	],
	"unknowable": [
		"............",
		"...yyyyyy...",
		"..y......y..",
		".y..rrrr..y.",
		"y..rr..rr..y",
		".y..rrrr..y.",
		"..y......y..",
		"...yyyyyy...",
		"rr........rr",
		"..rr....rr..",
		"....rrrr....",
	],
	"finger": [
		"y.y.y.y.....",
		"y.y.y.y.....",
		"y.y.y.y.....",
		"yyyyyyy.y...",
		"yyyyyyyyy...",
		"yyyyyyyy....",
		".yyyyyy.....",
		"..yyyy......",
		"..rrrr......",
	],
	"reflex": [
		"....y.......",
		"...yy.......",
		"..ywyyyyyy..",
		".ywwwwwwwy..",
		"..ywyyyyyy..",
		"...yy.......",
		"....y.......",
		"..........r.",
		"........rr..",
		"......rr....",
	],
	"parry": [
		"y..........y",
		"yy........yy",
		".yy......yy.",
		"..yy....yy..",
		"...yyyyyy...",
		"....ywwy....",
		"...yyyyyy...",
		"..rr....rr..",
		".rr......rr.",
		"rr........rr",
	],
	"colossal": [
		"...yyyyy....",
		"..yywwwyy...",
		"..ywyyywy...",
		"..yyyyyyy...",
		"yyyyyyyyyyy.",
		"yryyyyyyyry.",
		"yr.yyyyy.ry.",
		"...yy.yy....",
		"..yy...yy...",
		"..rr...rr...",
	],
	"misdirect": [
		"....yyyy....",
		"..yy....yy..",
		".y..rrrr..y.",
		"y..r....r..y",
		"y..r.ww.r..y",
		"y..r....r..y",
		".y..rrrr..y.",
		"..yy....yy..",
		"....yyyy....",
		"rrrrrrrrrrrr",
	],
	"bottomless": [
		"y..........y",
		"yy........yy",
		".yy......yy.",
		"..yyyyyyyy..",
		"..ycccccy...",
		"..ycbcbcy...",
		"..ycccccy...",
		"...ycccy....",
		"....yyy.....",
	],
	"bastion": [
		"yyy.yyy.yyy.",
		"yyyyyyyyyyy.",
		"yrrrrrrrrry.",
		"yrwwrrrrrry.",
		"yrwrrrrrrry.",
		"yrrrrrrrrry.",
		"yrrrryrrrry.",
		"yrrryyyrrry.",
		"yyyyyyyyyyy.",
	],
	"fleet": [
		"......yy....",
		".....yyw....",
		"....yyy.....",
		"rr.yyyyy....",
		"..yyyyyyy...",
		"rr..yyy.....",
		"....y.y.....",
		"...y...y....",
		"..y.....y...",
	],
	"afterimage": [
		"..r...y...w.",
		".rrr.yyy.www",
		"..r...y...w.",
		".rrr.yyy.www",
		"r.r.y.y.w.w.",
		"..r...y...w.",
		".r.r.y.y.w.w",
	],
	"phantom": [
		"....cccc....",
		"...cccccc...",
		"..ccbccbcc..",
		"..cccccccc..",
		"..cccccccc..",
		"..cccccccc..",
		"..cc.cc.cc..",
		"..c..c..c...",
	],
	"widedais": [
		"............",
		"y..........y",
		"yy...rr...yy",
		"yyyyyrryyyyy",
		"yy...rr...yy",
		"y..........y",
		"rrrrrrrrrrrr",
		"r.r.r.r.r.r.",
	],
	"overflow": [
		".....c......",
		"....ccc.....",
		"...ccecc....",
		"..ccceccc...",
		"..ccceccc...",
		"...cccccc...",
		"cc..ccc..cc.",
		".cc.....cc..",
		"..cccccccc..",
	],
	"echo": [
		"............",
		"..y.....y...",
		".y..y.y..y..",
		"y..y.w.y..y.",
		"y..y.w.y..y.",
		".y..y.y..y..",
		"..y.....y...",
	],
	"surge": [
		".....y......",
		"....yy......",
		"...yyw......",
		"..yyywwyyy..",
		"......wyyy..",
		".....yyy....",
		"....yy......",
		"...yr.......",
		"..r.........",
	],
	"archmage": [
		".....y......",
		"....yyy.....",
		"...yywyy....",
		"..yyyyyyy...",
		".yyyyyyyyy..",
		"rrrrrrrrrrr.",
		"..r.....r...",
		"..r.....r...",
	],
	"star": [
		".....y......",
		".....y......",
		"....ywy.....",
		"yyyyywyyyyy.",
		".yyywwwyyy..",
		"..yyywyyy...",
		"..yyyyyyy...",
		".yyy...yyy..",
		".yy.....yy..",
		"y.........y.",
	],
	"cinder": [
		"..y..y..y...",
		"...y.y.y....",
		".y.rrrrr.y..",
		"..rr...rr...",
		"yr..www..ry.",
		".r..wyw..r..",
		"yr..www..ry.",
		"..rr...rr...",
		".y.rrrrr.y..",
		"...y.y.y....",
		"..y..y..y...",
	],
	"bonecage": [
		"w..w..w..w..",
		"w..w..w..w..",
		"ww.w..w.ww..",
		".w.w..w.w...",
		".w.ww.ww.w..",
		".w..wwww.w..",
		".w...yy..w..",
		".w..yyyy.w..",
		".ww.yyyy.ww.",
		"rrrrrrrrrrrr",
	],
	"glacier": [
		"w....w....w.",
		"w....w....w.",
		".w...w...w..",
		".y...y...y..",
		"..y..y..y...",
		"..y..y..y...",
		"...y.y.y....",
		"...rrrrr....",
		"....rrr.....",
	],
	"thunder": [
		"...wy..wy...",
		"..wy..wy....",
		".wyyyywyyy..",
		"....wy..wy..",
		"...wy..wy...",
		"..wyyy.wyy..",
		".....r...r..",
		"....r...r...",
		"...r...r....",
	],
	"nullorb": [
		"....rrrr....",
		"..rroooorr..",
		".roooooooor.",
		".rooywwoooor",
		"rooywwooooor",
		"roooyyoooor.",
		".rooooooor..",
		"..rroooorr..",
		"....rrrr...y",
		"..........yy",
	],
	"leech": [
		"..r.....r...",
		".rrr...rrr..",
		".rwr...rwr..",
		".rrr...rrr..",
		"..r.....r...",
		".....r......",
		"....rrr.....",
		"....rwr.....",
		"....rrr.....",
		".....r......",
	],
	"sweep": [
		"...........y",
		".........yyy",
		".......yyyw.",
		".....yyyw...",
		"...yyyw.....",
		".yyyw.......",
		"yyw.........",
		"rr..........",
		"r.r.r.r.r.r.",
		"rrrrrrrrrrrr",
	],
	"grasp": [
		"y..y..y..y..",
		"y..y..y..y..",
		"yy.y..y.yy..",
		".yyyyyyyy...",
		".yyyyyyyy...",
		".yywyyyyy...",
		"..yyyyyy....",
		"...r..r.....",
		"..r.ww.r....",
		"...r..r.....",
	],
	"stomp": [
		"...yyyy.....",
		"...yyyy.....",
		"...yyyy.....",
		"..yyyyyy....",
		".yyyyyyyy...",
		".ywywywyy...",
		"............",
		"r.r......r.r",
		".r.r....r.r.",
		"rrrrrrrrrrrr",
	],
	"masonry": [
		"............",
		"..yyyyyyy...",
		".yywwyyyyy..",
		".ywyyyyyry..",
		".yyyyyyrry..",
		".yyyyyrrry..",
		"..yyyyyyy...",
		"..........r.",
		"........r...",
		"......r.....",
	],
	"crown": [
		"............",
		"y....w....y.",
		"yy..yyy..yy.",
		"yyy.yyy.yyy.",
		"yyyyyyyyyyy.",
		"ywyrywyrywy.",
		"yyyyyyyyyyy.",
		"rrrrrrrrrrr.",
	],
	"rite": [
		"............",
		"....yyyy....",
		"..yy....yy..",
		".y..rrrr..y.",
		"y..rwwwwr..y",
		"y.rwwoowwr.y",
		"y..rwwwwr..y",
		".y..rrrr..y.",
		"..yy....yy..",
		"....yyyy....",
	],
	"locked": [
		"....yyyy....",
		"...y....y...",
		"...y....y...",
		"........y...",
		".......y....",
		"......y.....",
		".....y......",
		".....y......",
		"............",
		".....y......",
	],
	"dread": [
		".....c......",
		".....cc.....",
		"....ccb.....",
		"...cbcb..c..",
		"...bccbb.c..",
		"..bbcecbbb..",
		"..bceeecbb..",
		"..bceeeecb..",
		"..bbceecbb..",
		"...bbccbb...",
		"....dbbd....",
		".....dd.....",
	],
}

# 5x7 glyphs (an optional 8th row is a descender). Lowercase maps to uppercase.
const GLYPHS := {
	"A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"B": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
	"C": [".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."],
	"D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
	"E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
	"F": ["#####", "#....", "#....", "####.", "#....", "#....", "#...."],
	"G": [".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".####"],
	"H": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"I": [".###.", "..#..", "..#..", "..#..", "..#..", "..#..", ".###."],
	"J": ["..###", "...#.", "...#.", "...#.", "#..#.", "#..#.", ".##.."],
	"K": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
	"L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
	"M": ["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"],
	"N": ["#...#", "#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#"],
	"O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
	"P": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
	"Q": [".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"],
	"R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
	"S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
	"T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
	"U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
	"V": ["#...#", "#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.."],
	"W": ["#...#", "#...#", "#...#", "#.#.#", "#.#.#", "#.#.#", ".#.#."],
	"X": ["#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#"],
	"Y": ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
	"Z": ["#####", "....#", "...#.", "..#..", ".#...", "#....", "#####"],
	"0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
	"1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
	"2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
	"3": ["####.", "....#", "....#", ".###.", "....#", "....#", "####."],
	"4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
	"5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
	"6": [".###.", "#....", "#....", "####.", "#...#", "#...#", ".###."],
	"7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
	"8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
	"9": [".###.", "#...#", "#...#", ".####", "....#", "....#", ".###."],
	" ": [".....", ".....", ".....", ".....", ".....", ".....", "....."],
	".": [".....", ".....", ".....", ".....", ".....", ".##..", ".##.."],
	",": [".....", ".....", ".....", ".....", ".##..", ".##..", "..#..", ".#..."],
	"!": ["..#..", "..#..", "..#..", "..#..", "..#..", ".....", "..#.."],
	"?": [".###.", "#...#", "....#", "...#.", "..#..", ".....", "..#.."],
	":": [".....", ".##..", ".##..", ".....", ".##..", ".##..", "....."],
	";": [".....", ".##..", ".##..", ".....", ".##..", ".##..", "..#..", ".#..."],
	"'": ["..#..", "..#..", ".#...", ".....", ".....", ".....", "....."],
	"\"": [".#.#.", ".#.#.", ".....", ".....", ".....", ".....", "....."],
	"-": [".....", ".....", ".....", ".###.", ".....", ".....", "....."],
	"+": [".....", "..#..", "..#..", "#####", "..#..", "..#..", "....."],
	"%": ["##..#", "##.#.", "...#.", "..#..", ".#...", ".#.##", "#..##"],
	"/": ["....#", "...#.", "...#.", "..#..", ".#...", ".#...", "#...."],
	"(": ["...#.", "..#..", ".#...", ".#...", ".#...", "..#..", "...#."],
	")": [".#...", "..#..", "...#.", "...#.", "...#.", "..#..", ".#..."],
	"[": [".###.", ".#...", ".#...", ".#...", ".#...", ".#...", ".###."],
	"]": [".###.", "...#.", "...#.", "...#.", "...#.", "...#.", ".###."],
	"<": ["...#.", "..#..", ".#...", "#....", ".#...", "..#..", "...#."],
	">": [".#...", "..#..", "...#.", "....#", "...#.", "..#..", ".#..."],
	"=": [".....", ".....", "#####", ".....", "#####", ".....", "....."],
	"_": [".....", ".....", ".....", ".....", ".....", ".....", "#####"],
	"#": [".#.#.", ".#.#.", "#####", ".#.#.", "#####", ".#.#.", ".#.#."],
	"&": [".##..", "#..#.", "#.#..", ".#...", "#.#.#", "#..#.", ".##.#"],
	"*": [".....", "#.#.#", ".###.", "#####", ".###.", "#.#.#", "....."],
	"·": [".....", ".....", ".....", "..#..", ".....", ".....", "....."],
	"—": [".....", ".....", ".....", "#####", ".....", ".....", "....."],
	"…": [".....", ".....", ".....", ".....", ".....", ".....", "#.#.#"],
	"✓": [".....", "....#", "...#.", "#.#..", ".#...", ".....", "....."],
	"◆": [".....", "..#..", ".###.", "#####", ".###.", "..#..", "....."],
	"◇": [".....", "..#..", ".#.#.", "#...#", ".#.#.", "..#..", "....."],
	"▶": [".#...", ".##..", ".###.", ".####", ".###.", ".##..", ".#..."],
	"★": ["..#..", "..#..", "#####", ".###.", ".###.", ".#.#.", "#...#"],
}

static var _cache := {}


## A bitmap FontFile built from GLYPHS. Its native size is 8px; use multiples of 8 (16, 24, 32…).
static func pixel_font() -> FontFile:
	if _cache.has("font"):
		return _cache["font"]
	var keys: Array = GLYPHS.keys()
	var cw := 6
	var ch := 8
	var img := Image.create_empty(cw * keys.size(), ch, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	for i in keys.size():
		var rows: Array = GLYPHS[keys[i]]
		for y in rows.size():
			var row: String = rows[y]
			for x in row.length():
				if row[x] == "#":
					img.set_pixel(i * cw + x, y, Color.WHITE)
	var f := FontFile.new()
	f.fixed_size = 8
	f.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_ENABLED
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	f.set_texture_image(0, Vector2i(8, 0), 0, img)
	f.set_cache_ascent(0, 8, 8.0)
	f.set_cache_descent(0, 8, 2.0)
	for i in keys.size():
		var c: String = keys[i]
		var codes: Array[int] = [c.unicode_at(0)]
		if c.length() == 1 and c >= "A" and c <= "Z":
			codes.append(c.to_lower().unicode_at(0))
		for cp in codes:
			f.set_glyph_advance(0, 8, cp, Vector2(cw, 0))
			f.set_glyph_offset(0, Vector2i(8, 0), cp, Vector2(0, -7))
			f.set_glyph_size(0, Vector2i(8, 0), cp, Vector2(cw, ch))
			f.set_glyph_uv_rect(0, Vector2i(8, 0), cp, Rect2(i * cw, 0, cw, ch))
			f.set_glyph_texture_idx(0, Vector2i(8, 0), cp, 0)
	var sys := SystemFont.new()
	sys.font_names = PackedStringArray(["Consolas", "Courier New", "monospace"])
	var fb: Array[Font] = [sys]
	f.fallbacks = fb
	_cache["font"] = f
	return f


static func icon(id: String) -> ImageTexture:
	var key := "icon_" + id
	if _cache.has(key):
		return _cache[key]
	var img := Image.create_empty(ICON_SIZE, ICON_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rows: Array = ICONS.get(id, ICONS["locked"])
	for y in mini(rows.size(), ICON_SIZE):
		var row: String = rows[y]
		for x in mini(row.length(), ICON_SIZE):
			var ch := row[x]
			if PALETTE.has(ch):
				img.set_pixel(x, y, PALETTE[ch])
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


## A diamond node frame: dark outline, colored border, dark fill with an inner ring.
static func diamond(size: int, border: Color, fill: Color, inner: Color) -> ImageTexture:
	var key := "dia_%d_%s_%s_%s" % [size, border.to_html(), fill.to_html(), inner.to_html()]
	if _cache.has(key):
		return _cache[key]
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := (size - 1) / 2.0
	var r := c
	for y in size:
		for x in size:
			var d := absf(x - c) + absf(y - c)
			if d > r + 0.01:
				continue
			var col := fill
			if d > r - 1.0:
				col = Color("12060a")
			elif d > r - 2.5:
				col = border
			elif d > r - 3.5 and d <= r - 2.5:
				col = fill.darkened(0.3)
			elif absf(d - (r - 4.5)) < 0.5:
				col = inner
			img.set_pixel(x, y, col)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


## An ornate pixel frame as a 9-slice StyleBox (art is drawn small and scaled up with nearest filtering).
static func frame_box(border: Color, fill: Color, scale: int = 3) -> StyleBoxTexture:
	var key := "frame_%s_%s_%d" % [border.to_html(), fill.to_html(), scale]
	if _cache.has(key):
		return _cache[key]
	var n := 16
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	img.fill(fill)
	var dark := Color("12060a")
	for i in n:
		for e in [0, n - 1]:
			img.set_pixel(i, e, dark)
			img.set_pixel(e, i, dark)
		for e in [1, n - 2]:
			img.set_pixel(i, e, border)
			img.set_pixel(e, i, border)
	for i in range(3, n - 3):
		for e in [3, n - 4]:
			img.set_pixel(i, e, border.darkened(0.45))
			img.set_pixel(e, i, border.darkened(0.45))
	# Corner studs
	for cx in [2, n - 3]:
		for cy in [2, n - 3]:
			img.set_pixel(cx, cy, border.lightened(0.4))
	img.resize(n * scale, n * scale, Image.INTERPOLATE_NEAREST)
	var sb := StyleBoxTexture.new()
	sb.texture = ImageTexture.create_from_image(img)
	var m := 5 * scale
	sb.texture_margin_left = m
	sb.texture_margin_right = m
	sb.texture_margin_top = m
	sb.texture_margin_bottom = m
	sb.content_margin_left = m + 6
	sb.content_margin_right = m + 6
	sb.content_margin_top = m + 2
	sb.content_margin_bottom = m + 2
	_cache[key] = sb
	return sb


## A chunky pill-shaped button frame.
static func pill_box(fill: Color, scale: int = 3) -> StyleBoxTexture:
	var key := "pill_%s_%d" % [fill.to_html(), scale]
	if _cache.has(key):
		return _cache[key]
	var w := 12
	var h := 8
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var dark := Color("12060a")
	for y in h:
		for x in w:
			var inset := 0
			if y == 0 or y == h - 1:
				inset = 2
			elif y == 1 or y == h - 2:
				inset = 1
			if x < inset or x > w - 1 - inset:
				continue
			var edge := x == inset or x == w - 1 - inset or y == 0 or y == h - 1
			img.set_pixel(x, y, dark if edge else (fill.lightened(0.25) if y == 1 or y == 2 else fill))
	img.resize(w * scale, h * scale, Image.INTERPOLATE_NEAREST)
	var sb := StyleBoxTexture.new()
	sb.texture = ImageTexture.create_from_image(img)
	var m := 3 * scale
	sb.texture_margin_left = m
	sb.texture_margin_right = m
	sb.texture_margin_top = m
	sb.texture_margin_bottom = m
	sb.content_margin_left = m + 10
	sb.content_margin_right = m + 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	_cache[key] = sb
	return sb
