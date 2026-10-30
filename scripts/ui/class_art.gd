extends RefCounted
## Pixel-art emblems for the seven classes, shown on the tip of each bough of the Grimoire and,
## large, in the class tooltip. 16x16, one character per pixel:
##   . clear   k outline   a main   b light   c accent   d dark   w white   r red   y gold

const ART := {
	"pyro": [  # a skull wreathed in hellfire
		"......y..y......",
		".....yr.yr..y...",
		"..y..rry.ry.ry..",
		"..ry.rrrrrr.r...",
		"...rrrkkkkrrr...",
		"...rkwwwwwwkr...",
		"..rkwwwwwwwwkr..",
		"..rkwkkwwkkwkr..",
		"..rkwkrwwkrwkr..",
		"...kwwwkkwwwk...",
		"....kwwwwwwk....",
		"....kwkwkwkk....",
		".....kkkkkk.....",
		"....rr....rr....",
		"...ry......yr...",
		"................",
	],
	"bone": [  # a crowned skull over crossed bones
		"....y.y..y.y....",
		"....yyyyyyyy....",
		"....kkkkkkkk....",
		"...kwwwwwwwwk...",
		"..kwwwwwwwwwwk..",
		"..kwkkwwwwkkwk..",
		"..kwkdwwwwkdwk..",
		"..kwwwwkkwwwwk..",
		"...kwwwwwwwwk...",
		"....kwkwkwkk....",
		"w...kkkkkkk...w.",
		"ww...........ww.",
		".www.......www..",
		"...wwww.wwww....",
		"..www.....www...",
		".ww.........ww..",
	],
	"war": [  # a horned helm over crossed axes
		"b..............b",
		"bb............bb",
		".bb..kkkkkk..bb.",
		"..bbkaaaaaakbb..",
		"...kaabbbbaak...",
		"..kaab....baak..",
		"..kaa.kkkk.aak..",
		"..kaakrrrrkaak..",
		"..kaaakkkkaaak..",
		"...kaaaaaaaak...",
		"....kkaaaakk....",
		"d.....kkkk.....d",
		".dd..........dd.",
		"...dd......dd...",
		".....dd..dd.....",
		"......dddd......",
	],
	"rime": [  # a snowflake on a kite shield
		"...kkkkkkkkkk...",
		"..kaaaaaaaaaak..",
		"..kaaawaawaaak..",
		"..kaaaawwaaaak..",
		"..kawaawwaawak..",
		"..kaawwwwwwaak..",
		"..kwwwwbbwwwwk..",
		"..kaawwwwwwaak..",
		"..kawaawwaawak..",
		"...kaaawwaaak...",
		"...kaawaawaak...",
		"....kaaaaaak....",
		".....kaaaak.....",
		"......kaak......",
		".......kk.......",
		"................",
	],
	"storm": [  # a lightning bolt from a thundercloud
		"....dddd........",
		"..dddddddd.dd...",
		".ddbbdddddddddd.",
		"ddbbbddddddbbddd",
		"dddddddddddddddd",
		".dddddyyddddddd.",
		"......yyy.......",
		".....yyyy.......",
		"....yyyyyyy.....",
		".......yyy......",
		"......yyy.......",
		".....yyw........",
		"....yyw.........",
		"....yw..........",
		"...yw...........",
		"...w............",
	],
	"void": [  # an eye at the heart of a spiral
		"....aaaaaaa.....",
		"..aaa.....aaa...",
		".aa..bbbbb..aa..",
		"aa.bbb...bbb.a..",
		"a.bb..kkkk.bb.a.",
		"a.b.kwwwwwwk.b.a",
		"a.bkwwckkcwwkb.a",
		"a.bkwwckkcwwkb.a",
		"a.b.kwwwwwwk.b.a",
		"a.bb..kkkk..b.a.",
		".a.bbb....bbb.a.",
		".aa..bbbbbb..aa.",
		"..aaa......aaa..",
		"....aaaaaaaa....",
		"................",
		"................",
	],
	"blood": [  # a chalice brimming over, one drop falling
		"................",
		"..kkkkkkkkkkkk..",
		"..kyrrrrrrrryk..",
		"..kyrrbrrrrryk..",
		"...kyrrrrrryk...",
		"...kyyrrrryyk...",
		"....kyyyyyyk....",
		".....kyyyyk.....",
		"......kyyk......",
		"......kyyk......",
		".....kyyyyk.....",
		"....kyyyyyyk....",
		"....kkkkkkkk....",
		"...........r....",
		"..........rrr...",
		"...........r....",
	],
}

const PAL := {
	"pyro": {"a": Color("c8402a"), "b": Color("ff9a3a"), "c": Color("ffd27a"), "d": Color("5a1a14")},
	"bone": {"a": Color("d8d0b8"), "b": Color("f2ead8"), "c": Color("ffd27a"), "d": Color("2a1a14")},
	"war": {"a": Color("8a6a5a"), "b": Color("e8dcc8"), "c": Color("ffd27a"), "d": Color("6a4a32")},
	"rime": {"a": Color("3a7aa8"), "b": Color("c8f0ff"), "c": Color("ffffff"), "d": Color("1a3a5a")},
	"storm": {"a": Color("8a90c8"), "b": Color("c8ccf2"), "c": Color("ffffff"), "d": Color("4a4e78")},
	"void": {"a": Color("6a2ab0"), "b": Color("a85aff"), "c": Color("ff3a6a"), "d": Color("2a0a4a")},
	"blood": {"a": Color("a81a2a"), "b": Color("ff6a6a"), "c": Color("ffd27a"), "d": Color("4a0a12")},
}

const BASE := {"k": Color("140a10"), "w": Color("f6f0e4"), "r": Color("d8282a"), "y": Color("f2c040"), ".": Color(0, 0, 0, 0)}

static var _cache := {}


static func emblem(cid: String) -> ImageTexture:
	if _cache.has(cid):
		return _cache[cid]
	var rows: Array = ART.get(cid, ART["pyro"])
	var pal: Dictionary = PAL.get(cid, PAL["pyro"])
	var img := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		var row: String = rows[y]
		for x in 16:
			var ch := row[x]
			var c: Color = pal.get(ch, BASE.get(ch, Color(0, 0, 0, 0)))
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	_cache[cid] = tex
	return tex
