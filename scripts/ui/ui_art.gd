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
	"chest": [
		"............",
		"..oooooooo..",
		".oryyyyyyro.",
		".orrrrrrrro.",
		".oyyywwyyyo.",
		"oooooccooooo",
		".orrryyrrro.",
		".oyrrrrrryo.",
		".orrrrrrrro.",
		".oyrrrrrryo.",
		".oooooooooo.",
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


static func has_icon(id: String) -> bool:
	return ICONS.has(id)


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


# =============================================================================
# The medieval kit: wooden boards with iron rivets, parchment, dark-wood buttons, inset slots.
# Pixel art drawn in code, then scaled up with nearest-neighbour so every pixel stays crisp.
# =============================================================================

const WOOD_DARK := Color("3b1f10")
const WOOD := Color("8a5530")
const WOOD_LIGHT := Color("a8693a")
const WOOD_GRAIN := Color("6d3f22")
const IRON := Color("6e6a6c")
const IRON_LIGHT := Color("b9b2ae")
const INK := Color("3a2010")
const CREAM := Color("f3e2bd")


## A wooden board: horizontal planks with grain and knots, a dark outline, a light top edge and
## iron rivets in the corners. The middle tiles, so the grain never stretches.
static func wood_box(scale: int = 2, alpha: float = 1.0, content: int = 10) -> StyleBoxTexture:
	var key := "wood_%d_%.2f_%d" % [scale, alpha, content]
	if _cache.has(key):
		return _cache[key]
	var n := 32
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for y in n:
		var plank := (y - 2) / 7
		var base := WOOD if plank % 2 == 0 else WOOD.lerp(WOOD_LIGHT, 0.35)
		for x in n:
			var c := base
			if (y - 2) % 7 == 0:
				c = WOOD_GRAIN.darkened(0.25)  # the seam between planks
			elif rng.randf() < 0.18:
				c = base.lerp(WOOD_GRAIN, 0.6)  # grain
			elif (x + plank * 11) % 23 == 0 and (y - 2) % 7 == 3:
				c = WOOD_GRAIN.darkened(0.3)  # a knot
			c.a = alpha
			img.set_pixel(x, y, c)
	# Frame: dark outline, a light bevel on top and left, a shadow on bottom and right
	for i in n:
		img.set_pixel(i, 0, WOOD_DARK)
		img.set_pixel(i, n - 1, WOOD_DARK)
		img.set_pixel(0, i, WOOD_DARK)
		img.set_pixel(n - 1, i, WOOD_DARK)
		if i > 0 and i < n - 1:
			img.set_pixel(i, 1, WOOD_LIGHT.lightened(0.15))
			img.set_pixel(1, i, WOOD_LIGHT)
			img.set_pixel(i, n - 2, WOOD_GRAIN.darkened(0.3))
			img.set_pixel(n - 2, i, WOOD_GRAIN.darkened(0.3))
	# Rivets
	for cx in [4, n - 5]:
		for cy in [4, n - 5]:
			for d in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1), Vector2i(0, 0)]:
				img.set_pixel(cx + d.x, cy + d.y, IRON)
			img.set_pixel(cx - 1, cy - 1, IRON_LIGHT)
			img.set_pixel(cx + 1, cy + 1, WOOD_DARK)
	img.resize(n * scale, n * scale, Image.INTERPOLATE_NEAREST)
	var sb := StyleBoxTexture.new()
	sb.texture = ImageTexture.create_from_image(img)
	var m := 7 * scale
	sb.texture_margin_left = m
	sb.texture_margin_right = m
	sb.texture_margin_top = m
	sb.texture_margin_bottom = m
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	sb.set_content_margin_all(content)
	_cache[key] = sb
	return sb


## Parchment: cream paper with a ragged, darker edge and a few stains. For text you read.
static func parchment_box(scale: int = 2, content: int = 14) -> StyleBoxTexture:
	var key := "parch_%d_%d" % [scale, content]
	if _cache.has(key):
		return _cache[key]
	var n := 32
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var paper := CREAM
	for y in n:
		for x in n:
			var edge := mini(mini(x, n - 1 - x), mini(y, n - 1 - y))
			var ragged := 1 + int(rng.randf() < 0.35)
			if edge < ragged:
				continue
			var c := paper
			if edge <= ragged:
				c = Color("9a6a3a")
			elif edge <= ragged + 1:
				c = paper.lerp(Color("c99a5e"), 0.6)
			elif rng.randf() < 0.08:
				c = paper.darkened(0.06)
			img.set_pixel(x, y, c)
	img.resize(n * scale, n * scale, Image.INTERPOLATE_NEAREST)
	var sb := StyleBoxTexture.new()
	sb.texture = ImageTexture.create_from_image(img)
	var m := 5 * scale
	sb.texture_margin_left = m
	sb.texture_margin_right = m
	sb.texture_margin_top = m
	sb.texture_margin_bottom = m
	sb.set_content_margin_all(content)
	_cache[key] = sb
	return sb


## A dark-wood button with a bevel: "normal", "hover", "pressed" or "disabled".
static func wood_button(state: String, scale: int = 2) -> StyleBoxTexture:
	var key := "wbtn_%s_%d" % [state, scale]
	if _cache.has(key):
		return _cache[key]
	var fill := {"normal": Color("4a2a18"), "hover": Color("6b3c20"), "pressed": Color("2e180c"), "disabled": Color("3a302c")}[state] as Color
	var n := 16
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in n:
		for x in n:
			var corner := (x == 0 or x == n - 1) and (y == 0 or y == n - 1)
			if corner:
				continue
			var c := fill
			if x == 0 or y == 0 or x == n - 1 or y == n - 1:
				c = Color("1e0f07")
			elif y == 1 and state != "pressed":
				c = fill.lightened(0.25)
			elif y == n - 2 and state != "pressed":
				c = fill.darkened(0.4)
			img.set_pixel(x, y, c)
	img.resize(n * scale, n * scale, Image.INTERPOLATE_NEAREST)
	var sb := StyleBoxTexture.new()
	sb.texture = ImageTexture.create_from_image(img)
	var m := 4 * scale
	sb.texture_margin_left = m
	sb.texture_margin_right = m
	sb.texture_margin_top = m
	sb.texture_margin_bottom = m
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 6
	sb.content_margin_bottom = 8 if state != "pressed" else 6
	_cache[key] = sb
	return sb


## An inset slot (skills, inventory): a recessed square, gilded when selected.
static func slot(size: int, selected: bool, ready: bool) -> ImageTexture:
	var key := "slot_%d_%s_%s" % [size, selected, ready]
	if _cache.has(key):
		return _cache[key]
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rim := Color("f2c35a") if selected else (WOOD_LIGHT if ready else WOOD_GRAIN)
	var inner := Color("2a160c") if ready else Color("1d120d")
	for y in size:
		for x in size:
			var corner := (x == 0 or x == size - 1) and (y == 0 or y == size - 1)
			if corner:
				continue
			var c := inner
			if x == 0 or y == 0 or x == size - 1 or y == size - 1:
				c = WOOD_DARK
			elif x == 1 or y == 1 or x == size - 2 or y == size - 2:
				c = rim
			elif x == 2 or y == 2:
				c = inner.darkened(0.5)  # the shadow inside the recess
			img.set_pixel(x, y, c)
	if selected:
		for cx in [2, size - 3]:
			for cy in [2, size - 3]:
				img.set_pixel(cx, cy, Color("fff0b0"))
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


## A red pixel heart (for Will), 9x8.
static func heart() -> ImageTexture:
	if _cache.has("heart"):
		return _cache["heart"]
	var rows := [".rr...rr.", "rwrr.rrrr", "rwrrrrrrr", "rrrrrrrrr", ".rrrrrrr.", "..rrrrr..", "...rrr...", "....r...."]
	var img := Image.create_empty(9, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in rows.size():
		for x in 9:
			var ch: String = rows[y][x]
			if ch == "r":
				img.set_pixel(x, y, Color("d8282e"))
			elif ch == "w":
				img.set_pixel(x, y, Color("ffb0a8"))
	var tex := ImageTexture.create_from_image(img)
	_cache["heart"] = tex
	return tex


# =============================================================================
# The SOUL kit: the HUD wears the King's state. At purity 0 it is corrupted: blackened, with a
# blood-red border, thorns along the edges and red cracks glowing in it. As he remembers it turns
# to iron, then bronze, and at the end it is light and hopeful: warm, translucent, gold-edged,
# with a little gem of light at each corner. Purity is quantized to the 7 steps of the story.
# =============================================================================

static func _q(p: float) -> float:
	return roundf(clampf(p, 0.0, 1.0) * 6.0) / 6.0


## The palette at purity p: [fill, border, border light, accent (cracks / gems), text, title]
static func soul_colors(p: float) -> Array:
	p = _q(p)
	var fill := Color(0.04, 0.015, 0.05).lerp(Color(0.16, 0.12, 0.08), p)
	var border: Color
	if p < 0.5:
		border = Color(0.32, 0.04, 0.08).lerp(Color(0.42, 0.38, 0.4), p * 2.0)      # blood -> iron
	else:
		border = Color(0.42, 0.38, 0.4).lerp(Color(0.95, 0.78, 0.4), (p - 0.5) * 2.0)  # iron -> gold
	var light := border.lightened(0.35)
	var accent := Color(1.0, 0.18, 0.22).lerp(Color(1.0, 0.95, 0.75), p)
	var text := Color(0.86, 0.74, 0.82).lerp(Color(1.0, 0.97, 0.9), p)
	var title := Color(0.95, 0.3, 0.32).lerp(Color(1.0, 0.85, 0.45), p)
	return [fill, border, light, accent, text, title]


## A HUD frame for purity p. alpha: how solid the fill is (it grows more see-through as he heals).
static func soul_box(p: float, alpha: float = 0.85, content: int = 8, scale: int = 2) -> StyleBoxTexture:
	p = _q(p)
	var key := "soul_%.2f_%.2f_%d_%d" % [p, alpha, content, scale]
	if _cache.has(key):
		return _cache[key]
	var cols := soul_colors(p)
	var fill: Color = cols[0]
	fill.a = alpha * lerpf(1.0, 0.72, p)
	var border: Color = cols[1]
	var light: Color = cols[2]
	var accent: Color = cols[3]
	var n := 24
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	for y in range(2, n - 2):
		for x in range(2, n - 2):
			img.set_pixel(x, y, fill)
	for i in range(2, n - 2):
		for e in [2, n - 3]:
			img.set_pixel(i, e, border)
			img.set_pixel(e, i, border)
		img.set_pixel(i, 3, light if p >= 0.5 else border.darkened(0.3))  # a bright inner rule when pure
	if p < 0.5:
		# Thorns: little spikes leaning out of the border, and cracks glowing red in it
		var thorns := int((0.5 - p) * 14.0)
		for k in thorns:
			var along := 4 + (k * 7) % (n - 8)
			var side := k % 4
			var pts := [Vector2i(along, 1), Vector2i(along, n - 2), Vector2i(1, along), Vector2i(n - 2, along)]
			var tip: Vector2i = pts[side]
			img.set_pixel(tip.x, tip.y, border.darkened(0.2))
			var lean: Vector2i = [Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, 1)][side]
			var tip2 := tip + lean
			if tip2.x >= 0 and tip2.y >= 0 and tip2.x < n and tip2.y < n:
				img.set_pixel(tip2.x, tip2.y, border.darkened(0.4))
		for k in int((0.5 - p) * 10.0):
			var cx := 2 if k % 2 == 0 else n - 3
			var cy := 4 + rng.randi() % (n - 8)
			if k % 3 == 0:
				img.set_pixel(cy, cx, accent)
			else:
				img.set_pixel(cx, cy, accent)
	# Corners: a jagged blot when corrupt, a gem of light when pure
	for cx in [2, n - 3]:
		for cy in [2, n - 3]:
			if p >= 0.5:
				img.set_pixel(cx, cy, accent)
				img.set_pixel(cx + (1 if cx == 2 else -1), cy, light)
				img.set_pixel(cx, cy + (1 if cy == 2 else -1), light)
			else:
				img.set_pixel(cx, cy, border.darkened(0.5))
				img.set_pixel(cx + (-1 if cx == 2 else 1), cy, border.darkened(0.5))
	img.resize(n * scale, n * scale, Image.INTERPOLATE_NEAREST)
	var sb := StyleBoxTexture.new()
	sb.texture = ImageTexture.create_from_image(img)
	var m := 5 * scale
	sb.texture_margin_left = m
	sb.texture_margin_right = m
	sb.texture_margin_top = m
	sb.texture_margin_bottom = m
	sb.set_content_margin_all(content)
	_cache[key] = sb
	return sb


## A button in the soul style.
static func soul_button(state: String, p: float) -> StyleBoxTexture:
	p = _q(p)
	var key := "soulbtn_%s_%.2f" % [state, p]
	if _cache.has(key):
		return _cache[key]
	var cols := soul_colors(p)
	var base: Color = (cols[0] as Color).lerp(cols[1], 0.35)
	var fill: Color = {"normal": base, "hover": base.lightened(0.18), "pressed": base.darkened(0.3), "disabled": base.darkened(0.45)}[state]
	var edge: Color = cols[1] if state != "hover" else cols[2]
	var n := 16
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in n:
		for x in n:
			if (x == 0 or x == n - 1) and (y == 0 or y == n - 1):
				continue
			var c := fill
			if x == 0 or y == 0 or x == n - 1 or y == n - 1:
				c = edge
			elif y == 1 and state != "pressed":
				c = fill.lightened(0.15)
			img.set_pixel(x, y, c)
	img.resize(n * 2, n * 2, Image.INTERPOLATE_NEAREST)
	var sb := StyleBoxTexture.new()
	sb.texture = ImageTexture.create_from_image(img)
	sb.texture_margin_left = 6
	sb.texture_margin_right = 6
	sb.texture_margin_top = 6
	sb.texture_margin_bottom = 6
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 6
	sb.content_margin_bottom = 7
	_cache[key] = sb
	return sb


## The inset you read text in: a dark, sunken slip while corrupt; clean parchment once he heals.
static func soul_inset(p: float) -> StyleBox:
	if _q(p) >= 0.5:
		return parchment_box(2, 14)
	var key := "soulinset_%.2f" % _q(p)
	if _cache.has(key):
		return _cache[key]
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.0, 0.0, 0.45)
	sb.border_color = (soul_colors(p)[1] as Color).darkened(0.3)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(14)
	_cache[key] = sb
	return sb


## Text colour inside soul_inset at purity p.
static func inset_text(p: float) -> Color:
	return INK if _q(p) >= 0.5 else soul_colors(p)[4]


## A skill slot in the soul style.
static func soul_slot(size: int, selected: bool, ready: bool, p: float) -> ImageTexture:
	p = _q(p)
	var key := "soulslot_%d_%s_%s_%.2f" % [size, selected, ready, p]
	if _cache.has(key):
		return _cache[key]
	var cols := soul_colors(p)
	var rim: Color = cols[3] if selected else (cols[1] if ready else (cols[1] as Color).darkened(0.5))
	var inner := (cols[0] as Color).darkened(0.2)
	inner.a = 0.85
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in size:
		for x in size:
			if (x == 0 or x == size - 1) and (y == 0 or y == size - 1):
				continue
			var c := inner
			if x == 0 or y == 0 or x == size - 1 or y == size - 1:
				c = rim
			elif selected and (x == 1 or y == 1 or x == size - 2 or y == size - 2):
				c = rim.darkened(0.25)
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


## The heart, from a black, thorn-pricked heart to a bright one with a gold glint.
static func soul_heart(p: float) -> ImageTexture:
	p = _q(p)
	var key := "soulheart_%.2f" % p
	if _cache.has(key):
		return _cache[key]
	var rows := [".rr...rr.", "rwrr.rrrr", "rwrrrrrrr", "rrrrrrrrr", ".rrrrrrr.", "..rrrrr..", "...rrr...", "....r...."]
	var red := Color(0.35, 0.03, 0.08).lerp(Color(0.9, 0.16, 0.18), p)
	var hi := Color(0.6, 0.15, 0.2).lerp(Color(1.0, 0.9, 0.6), p)
	var img := Image.create_empty(9, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in rows.size():
		for x in 9:
			var ch: String = rows[y][x]
			if ch == "r":
				img.set_pixel(x, y, red)
			elif ch == "w":
				img.set_pixel(x, y, hi)
	if p < 0.5:
		img.set_pixel(4, 3, Color(0.05, 0.0, 0.02))  # a thorn through it
		img.set_pixel(5, 2, Color(0.05, 0.0, 0.02))
		img.set_pixel(6, 1, Color(0.05, 0.0, 0.02))
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex
