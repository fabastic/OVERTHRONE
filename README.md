# OVERTHRONE — prototype

You are **the Hollow King**, and the city of Vael is terrified of you.

**By day** you walk Vael in first person: a medieval city threaded with aether-tech that grows a little more every day. You talk to its people, buy and find better blades, open chests, and hunt the day's boss out past the walls. **At dusk** a man in white walks up to you, wherever you are, and takes you to the corner table of the Hollow Flagon.

**By night** he plays a board game with you, Inscryption-style. The board is the map of your life, six regions across the table, and each region ends in a **challenger**: Wren the Squire, Ser Corvin, the Lion of Sunfield, Brother Ashe, Saint Alder, the Dawnbringer. They look like ordinary heroes come to dethrone a tyrant. Only slowly, memory by memory, does the truth surface: every one of them was you.

Land on a challenger's square and the game drops into the arena. You become the vast final boss in first person, and the challenger is an AI hero who learns everything you throw at him. Outlast him and he ascends, giving back a **memory** (a story reveal), a **relic** (a permanent bonus), and you wake to the next day.

As your hands purify, the city's fear turns to wariness, then to reverence. And the Stranger's white robe greys, then blackens. On night five he lowers his hood. On night seven there is no board.

## Run it

1. Unzip `Downloads/Godot_v4.7.2-stable_win64.exe.zip` anywhere and launch Godot.
2. **Import** → select `OVERTHRONE/project.godot` → **Import & Edit**.
3. Press **F5**.

## Controls

**By day (Vael):**

| Input | Action |
|---|---|
| WASD / arrows, SHIFT | Walk, run |
| Mouse | Look |
| LMB | Swing your blade (on the beat: one swing every few ticks, set by the weapon) |
| Q | Cast the selected skill |
| RMB | Parry. Foes show a red tick countdown over their heads; parry on the last beat |
| E | Talk, open a chest, examine a secret, pick up a page, look in the mirror |
| M / TAB | The map of Vael (the world holds still while you read it) |
| 1-5 / mouse wheel | Select skill |

**At night (the arena):**

| Input | Action |
|---|---|
| Mouse | Aim (you're seated, so look is clamped) |
| LMB | Cast the selected skill |
| RMB | **Parry**: raise your guard as his blade (or holy bolt) lands. You take 15% |
| A/D or ←/→ | **Lean** along the dais. Shift away mid-swing and his blow only grazes you (30%). Bolts too |
| 1-5 / mouse wheel | Select skill |
| ESC | Pause |
| F2 | Cycle pixel size |

**On the board:** SPACE or click advances the King one tile. T opens the Throne of Thought.

**On the Throne screen:**
- Q/E or TAB switch pages.
- Arrows/WASD move, SPACE or click selects.
- ENTER continues.
- ESC leaves the Rite.

In any dialogue or card, **1-9** pick a choice and **ENTER** presses the first button.

## New-player guidance

A one-time **GUIDANCE** hint appears the first time each thing matters: moving on the board, events, casting, switching skills, parrying (the game briefly slows the first time his blade glows red), leaning, his death and learning, the Rite, adapting, stars, checkpoints, Crowns, and each new move a challenger brings.

## Your hands tell the story

They are built like real hands: a palm as long as the fingers, three hinged segments to every finger (middle longest, pinky set low), knuckles on an arc, a thumb rooted at the heel of the hand, tendons, creases, a signet ring on the right index finger and a pale band where a ring used to be on the left. They are held up before you, backs toward your eyes.

At the start they are corrupted: grey and gaunt, the fingers 35% longer and thinner, ink-black from the fingertips up, swollen knuckles, long black claws, peeling skin, crooked joints that twitch, red cracks, thorns, an iron shackle with a broken chain, and smoke. Every memory you restore purifies them: the fingers shorten and straighten, the claws shrink back into nails, the skin warms, the veins turn gold, the shackle becomes a gold bracelet, and smoke becomes motes of light.

**They move.** Every hand blends between poses: relaxed, open, clawed, a fist, a pointing finger, a sword in a hammer grip, the wand in a pencil grip, a guard with crossed wrists. Each school of magic is cast with its own gesture, and the palm glows and sparks in the spell's colour: Hellfire is an open-palm push, Bone a two-fisted slam, Rime a two-finger point, Storm a raised finger and a snap, Void a claw that clenches into a fist, Blood a palm turned up to beckon, Warlord a flat sweep, and the great spells (Eclipse, Time Rend, Falling Star, Phantom Hands) lift both hands to the sky. At rest the fingers roll and fidget, and the wand turns.

## He rises above you

Each time he returns he is bigger and brighter, with an aura and rising motes. From the second fight on he descends into the hall through a pillar of light. Later challengers grow gold shoulder spikes and wings, and from the fourth they levitate. When he wins, he rises into the air.

## The loop

```
TITLE -> DAY 1
DAY: wake somewhere in Vael · walk, talk, fight, loot · today's boss waits in its lair
  -> DUSK: the Stranger walks up to you -> the Hollow Flagon, his line for the night
NIGHT: the board (walk the tiles: story · event · treasure · class altar)
  -> CHALLENGER square -> arena fights, with the Throne of Thought between his deaths
      0 stars  -> NOT YET WORTHY: retry from your last checkpoint (every 3 fights)
      1+ stars -> he ascends -> Crown tally -> MEMORY RESTORED + relic
  -> you WAKE (a new spot each day) -> Remembrance -> the next DAY
NIGHT 7: no board. The final fight is against the Stranger -> the ending
(a new cycle keeps Crowns, classes and Eternity)
```

**Ticks.** All combat, by day and by night, runs on a fixed 0.25s tick. Clicks only queue an action, which resolves on the next tick, so mashing does nothing. Cooldowns, the global cooldown (2 ticks), windups and your parry window are all counted in ticks. His windup shows as a red countdown over his head: parry when it reads 1. Holy bolts land on a tick too.

**The learning curve is per fight, and exponential.**
- Every skill he sees during a fight counts as one fight of experience when he dies.
- His mastery climbs 3% → 9% → 21% → 46% → MASTERED over 5 fights.
- So your starter attacks take him ~5 fights. Each new power you pull takes him another ~5.
- Mastery sets both his chance to counter a skill and how fast he does it.

**He grows exponentially too.** Every death multiplies his vitality and blade (×1.14), and adds speed and *poise* (a chance to walk through your hits). The first hero is hopeless against you; the late game is a battle to delay him.

**Parry.** Right-click as a blow lands. You're enormous, so it only hits a lesser part of you:
- Parried blows deal 25% (10% with the Obsidian Scale perk).
- The red-glowing blade is your timing cue.

**Stars and checkpoints:**
- Stars light up at 5, 8 and 11 of his deaths, shown on the progress bar under his health.
- One star is required to pass him.
- A checkpoint saves every 3 fights. Failing rolls back his memory, your Dread, perks and pulls to that checkpoint.

## The heroes

Each has more moves of his own. All of his blows can be parried.
1. **The Squire:** strike
2. **The Knight:** + LUNGE from range
3. **The Champion:** + HOLY BOLT thrown at your face
4. **The Paladin:** + JUDGMENT LEAP onto the dais (1.8× damage)
5. **The Saint:** every move, faster
6. **The Avatar of Dawn:** everything, at full strength

## Vael, by day

- **The city:** walls at ±38 with east, west and south gates, a fountain plaza, the Hollow Flagon, the Rusted Cog, the Lantern & Lens (and its mirror), the Cathedral of Gears, a clocktower, Old Hennik's forge, stables and houses. Outside: a graveyard, a river and bridge, and six **lairs** (the Burned Farm, the Old Bridge, the Sunfield Pit, the Pyre, the Gilded Shrine, the Dawnspire).
- **A day** lasts 5 minutes (talking stops the clock). Halfway through you may glimpse a man in white in the distance. At dusk he comes for you.
- **Day bosses:** one per day, each tied to a past self (Mordrek, the Bridge Warden, the Pit Master, the High Inquisitor, the Gilded Prophet, the Crown's Herald). Killing one is a **deed**: +10% damage and +25 Will for every night after, and Crowns at the next prestige.
- **Tone:** people fear you, then grow wary, then treat you as a saint, following your purity. Afraid, they give their services free (you may pay anyway); as a saint you get half price. You can also ask anyone about the man in white, or demand tribute. The Stranger notices how kind or cruel you were.
- **Services:** Marta's bread (heal), Hennik's forge (six weapons, one new tier per day), Sister Ivy's blessing and Greta's ale (+Will tonight), Liore's aether tuning (+20% weapon damage, up to 3), Pip, Captain Rolan's bounty, Oswin's songs, Widow Ansel's empty grave, and Toms, who lets you wait for dusk.
- **Loot:** 11 chests, some sealed with Dread. Graffiti on the walls, all in your handwriting.
- **Blades:** ten weapons built as real swords (fuller, quillons, wrapped grip, pommel, glowing runes): a rusted shortsword, a falchion, a runed longsword, a Cog-Axe, a Wardensteel greatsword, the Arcbrand, a Lionfang sabre, a Phase Halberd, the Sunforged Edge, and one you have to find. You swing in a diagonal arc on the beat. Swords hang on Hennik's rack (more each day), over the Flagon's door, in the Watch armoury and over the gladiators' graves.
- **Ambushes:** from day 2 the Crownless jump you twice a day, out of the crowd behind you.
- **The town crier** shouts the day's news from the plaza.
- **Tech** rises every day: aether globes replace torches (day 2), conduits light the avenues (3), lanterns float over the plaza (4), holo-banners (5), an airship (6).
- **Dread carries over** between day and night. Ascension perks **reset every night**, and each night's perks are 10% stronger.

## The Lamplighter (a story of its own)

Edda has lit Vael's aether lamps for fifty years, and every night now lamps go dark: the **Crownless**, a cult in empty-crown masks, pry out their hearts to "feed the Voice". Each day she asks for your help: Weaver's Lane, the Miller's Cellar, behind the stables, the cathedral vigil, the Gearwright's camp, the Undercroft beneath the Dawnspire road, and on the last day, a lamp. Every errand is a fight you **win**, led by a named elite, and each one grants a **Boon of Vael** that makes you stronger against the challengers at night:

| Boon | Effect at night |
|---|---|
| Edda's First Lamp | +10% damage to challengers |
| Watch Whistle | every challenger starts at 90% |
| Pip's Lucky Button | +15 Dread whenever a challenger falls |
| Ivy's Vigil Candle | parry window +0.05s |
| Liore's Clear Lens | challengers learn 10% slower |
| The Stolen Lamp-Heart | +40 max Will |
| The Last Lamp of Vael | +10% damage; the Stranger starts at 90% |

Finished errands also add Crowns to the next prestige. (And Edda knew who you were all along.)

## Secrets and the Chronicle

Twelve **secrets** hide the King's true story where it happened: a sword in a burned stump with WREN on the crossguard (pull it free once you remember Wren), Corvin's split shield by the bridge, the Lion's laurel in the pit sand, Ashe's ledger with your own name crossed out, Alder's smiling mask, an empty throne of black glass under the Dawnspire, a statue with its face chiselled off, a child's chalk drawing, initials in the Flagon's wood, a cracked coronation bell, a clock with a thirteenth hour, and a ring-shaped hollow in the river silt. Some only tell everything once you remember enough. Ten torn **pages of the Chronicle of Vael** tell how the crown was forged from a fallen star, and what it wants. Each find pays Crowns; finding them all pays more.

## The map: the land was drawn from it

Press **M**. Vael is drawn on old, coffee-stained parchment, and the island is made from that same sheet: every dark stain on the map is water in the world (sea and lagoons, with a sandy shore where the stain's tide-mark dried) and the light paper is the land. The city, the roads and every place you need stay dry. A minimap sits in the corner.

## Board skirmishes: fights you can win

Each chapter of the board now has a **SKIRMISH** tile before its challenger: a Shade from that part of the King's past (the Scarecrow Knight, the Deserter's Shade, the Crowd's Champion, the Penitent Flame, the Hollow Pilgrim, the Crown's Echo). It has one life and learns nothing. Banish it for Crowns, Dread, a reforged skill and a **trophy** (+4% damage to every challenger for the rest of the run). Lose and you lose nothing but the prize.

## Look

Everything but your hands is pixel art in the spirit of a pixel dungeon crawler: chunky stone bricks with dark mortar, cobbles, plank doors, shingle roofs, plaster and timber, pixel grass, bark and leaves, water and sand, all mapped in world space so every texel is the same size. People are built with big block heads and painted pixel faces (beards, stubble, goggles, veils, bandanas, porcelain masks) and dress for their trade. The arena is a pixel dungeon hall. The UI wears the King's state and stays out of the way. At first it is corrupted: black-violet panels with blood-red, thorned borders and red cracks glowing in them, a dark slip for anything you read, a blackened heart with a thorn through it. With every memory it lightens, through iron and bronze, until it is warm, translucent and gold-edged with gems of light at the corners, the text inked on parchment and the heart bright. The day HUD is just a purse and clock, a compass, two tracker lines, a slim Will bar over the skill slots, a hair-thin swing meter under the crosshair, and a small minimap; everything else (secrets, pages, boons, your blade) is on the map (M). The board is a candlelit map in the Inscryption manner, crowded with little cone forests in each region's colours and inked with dashed trails, with the Stranger seated across the table.

## The Stranger and the last night

He sits across the board every night, corrupting as you purify. The city drops hints that he is you all week, and on night 5 you are told. On night 7 he fights you himself: one long fight, with everything you can do already learned (your favorite skill perfectly). His counters come from how you played all week:
- **Parrier:** every third blow burns violet and cannot be parried. Lean out of it.
- **Leaner:** his blade follows your lean every time.
- **Caster:** your favorite skill is nullified, he blinks out of projectiles, and every fifth cast is mirrored back at you.

At 66% and 33% of his life the fight stops and you choose: make him forget your favorite skill, restore half your Will, or deal +35% damage for the rest of the night.

## Classes

32 skills in 7 classes. The Rite of Summoning only draws from classes you have unlocked. Your **active class** grants its passive.

| Class | Cost | Passive (while active) |
|---|---|---|
| Pyromancer | free | Hellfire skills +25% damage |
| Ossuarch | free | +40 max Will |
| Warlord | 25 | Leaning grazes deal 15%; lean 50% faster. Skills use your reach: Titan Sweep, Crushing Grasp, Earthshaker, Hurl Masonry |
| Rimewarden | 30 | Slowed/frozen/bound heroes take +30% |
| Stormcaller | 40 | -20% cooldowns |
| Voidwalker | 50 | He learns 20% slower |
| Bloodpriest | 60 | Heal 10% of damage dealt |

Unlock classes from their sigil on the Grimoire page, or at half price at a board **Class Altar**. **Skills reset each chapter** to the starter kit. Then **Remembrance** lets you carry a few from your past (2 + chapter/2), in the strongest version your ascension allows: up to rank II in chapter 2, III in chapter 3, and so on. Ascension perks and classes are kept for the whole run.

## Relics (one per memory restored)

Borrowed Sword (+10% damage) · Broken Oath-Ring (parry window +0.06s) · Champion's Laurel (+30% Dread) · Cracked Censer (he learns 10% slower) · Saint's Ashes (+25% Will) · Ember of Dawn

## The Throne of Thought (Tree of Life)

- **Crown:** your loadout (4 slots, 5 with Fifth Finger).
- **Roots:** the Rite of Summoning (gacha). Stop the needle: gold = legendary, violet = rare. Duplicates reforge a skill: +1 rank, and he forgets two fights of it.
- **GRIMOIRE page:** one bough per class, skills inward and the class sigil at the tip. Sealed "?" nodes are ones you haven't summoned. Red pips show how well he knows a skill, gold pips its rank.

| School | Skills (counter he learns) |
|---|---|
| Hellfire | Hellfire Orb (sidestep), Soul Volley (sidestep), Hellfire Pillar (roll), Falling Star (sprint) |
| Bone | Bone Spires (roll), Throne Quake (leap), Ossuary Wall (vault), Grave Tide (double leap) |
| Rime | Rime Lance (parry), Frost Bloom (roll, slows him), Time Rend (resist, freezes him 2s) |
| Storm | Sky Lash (ward), Doom Mark (dash), Crimson Rain (weave) |
| Void | Gravemaw (anchor), Abyssal Rift (step out), Phantom Hands (fall back), Eclipse of Self (kindle) |
| Blood | Grasping Chains (break away), Hex of Frailty (cleanse), Blood Siphon (break line, heals you), Ghoul Brood (cleave) |

- **ASCENSION page** (Dread, kept all run). Six branches of four:
  - **Tyranny:** Iron Throne → Wrath → Crushing Presence → Colossal Will
  - **Cunning:** Quickened Malice → Unreadable → Mind Fog → Misdirection
  - **Hunger:** Dread Harvest → Generous Rites → Fated Hand → Bottomless Rite
  - **Guard:** Hardened Talons → Obsidian Scale (parry 8%) → Riposte → Iron Bastion
  - **Motion:** Fleet Throne → Afterimage (graze 15%) → Phantom Step → Wide Dais
  - **Sorcery:** Overflow → Echo → Arcane Surge → Archmage
- **ETERNITY page** (Crowns, permanent):
  - Colossus (+Will)
  - Tyrant's Might (+damage)
  - Ancient Grudge (starting Dread)
  - Favored Fate (wider Rite zones)
  - Unknowable (+1 fight for him to master anything)
  - Fifth Finger (+1 loadout slot)
  - Titan's Reflex (wider parry window)

## Code map

Everything is built in code; the only scene is an empty `scenes/main.tscn`.

- `scripts/overworld.gd`: **Vael by day**: the city and outside, collisions (rect-based `resolve()`), sun and sky by time of day, NPC dialogue and services, chests, day combat on ticks, the HUD, dusk, the day autoplay bot
- `scripts/dialogue.gd`: **all of Vael's words**: NPCs by tone, the Stranger's nightly lines and the reveal, hints, graffiti, weapons and day bosses
- `scripts/npc.gd`: people of Vael (cower, watch, kneel by tone; townsfolk wander and mutter)
- `scripts/day_enemy.gd`: foes by day (thugs, archers, automatons and the six day bosses), thinking on ticks
- `scripts/stranger.gd`: the Stranger's model: corrupts as you purify, hood down after the reveal
- `scripts/sidestory.gd`: **the Lamplighter's story, the secrets, the Chronicle, the crier and ambush shouts**
- `scripts/pixtex.gd`: pixel textures (bricks, cobbles, planks, shingles, ground, bark, leaves, plaster, metal, cloth, tiles, water, grain) and pixel faces; `pixelize()` turns flat-coloured props into pixel art
- `scripts/swords.gd`: detailed blades for every weapon (in hand, on racks, in the stump)
- `scripts/ui/parchment.gd`: the stained parchment and `wetness()`, shared by the map and the island
- `scripts/ui/vael_map.gd`: the map and the minimap; `scripts/ui/compass.gd`: the compass strip
- `scripts/board.gd`: the tabletop board (the Flagon's corner table, with the Stranger seated across it), the King's piece, tiles, fog, region landmarks and camera
- `scripts/story.gd`: **all story content**: chapters, tile texts, choice events, memories, relics and the ending. Edit this file to rewrite the story.
- `scripts/main.gd`: world, HUD, the day / dusk / night flow, board tile events, the tick-driven fight loop, parry resolution, checkpoint/try-again, prestige flow, the last night, autoplay bot
- `scripts/game_state.gd` (autoload): skills, heroes, perks, Eternity, the per-fight mastery curve, stars, checkpoints, Crowns. **Most balance numbers live here.**
- `scripts/sfx.gd` (autoload): every sound is synthesized in code
- `scripts/hero.gd`: hero AI, his moves, statuses (slowed, frozen, hexed, walled), counter verbs, three model forms
- `scripts/hero_bolt.gd`: his holy bolt
- `scripts/boss.gd`: your camera, hands, casting, parry
- `scripts/attacks/*.gd`: one script per skill family (`zone.gd` drives Pillar, Falling Star, Frost Bloom and the rain drops)
- `scripts/ui/throne_tree.gd`: the three-page Tree of Life
- `scripts/ui/prestige_screen.gd`: the ascension, stars and Crown tally sequence
- `scripts/ui/star_bar.gd`, `hotbar.gd`: HUD pieces
- `scripts/ui/ui_art.gd`: pixel font, 12×12 icons (edit the text grids), frames and buttons

## Testing

```bash
Godot_v4.7.2-stable_win64_console.exe --headless --path . -- --autoplay --fast --quit-at-end
```

The bot plays everything: by day it walks out through a gate to the day's boss and fights it (and anything on the way); at night it aims, casts, parries ~65% of blows on the tick before they land, and leans out of violet blades. Days last 40s in autoplay. Extra flags:
- `--passive`: the bot never attacks, which exercises TRY AGAIN
- `--pure`: show the fully purified hands
- `--preview-day`, `--preview-final`, `--preview-board`, `--preview-throne`, `--preview-rite`, `--preview-heroes`, `--preview-prestige`: jump straight to a screen for screenshots
- `--level=N`: start a preview on day / night N
- `--shot=file.png` (`--shot-delay=S`): save a screenshot after S seconds and quit (needs a renderer, e.g. `xvfb-run ... --rendering-driver opengl3`)
- `--trace-bot`: print the day bot's position every half second
- `--pos=x,z,yaw`: (with `--preview-day`) stand somewhere in Vael; `--talk=<npc>` opens a conversation; `--map` opens the map
- `--gesture=<skill>`: (with `--preview-heroes`) freeze that skill's hand gesture half way

Last full run (`--autoplay --fast --quit-at-end`): seven days and six nights end to end, 0 script errors. By day the bot won all seven of the Lamplighter's errands (all seven boons) and slew five of the six day bosses. On the board it won all six skirmishes (six trophies), outlasted 12 / 10 / 11 / 7 / 9 / 8 of the challengers' lives, then beat the Stranger on the last night (playstyle read as "parry"; phase choices: forget, forget everything). Every dialogue, service, secret, page, chest, the forge and the map were also exercised by a scripted pass. It has not yet been played by hand with mouse and keyboard.
