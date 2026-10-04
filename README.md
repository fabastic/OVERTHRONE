# OVERTHRONE — prototype

You are **the Hollow King**: a carved piece on a candlelit tabletop, Inscryption-style. The board is the map of your life, six regions across the table, and each region ends in a **challenger**: Wren the Squire, Ser Corvin, the Lion of Sunfield, Brother Ashe, Saint Alder, the Dawnbringer. They look like ordinary heroes come to dethrone a tyrant. Only slowly, memory by memory, does the truth surface: every one of them was you.

Land on a challenger's square and the game drops into the arena. You become the vast final boss in first person, and the challenger is an AI hero who learns everything you throw at him. Outlast him and he ascends, giving back a **memory** (a story reveal), a **relic** (a permanent bonus) and the road to the next region.

## Run it

1. Unzip `Downloads/Godot_v4.7.2-stable_win64.exe.zip` anywhere and launch Godot.
2. **Import** → select `OVERTHRONE/project.godot` → **Import & Edit**.
3. Press **F5**.

## Controls

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

## New-player guidance

A one-time **GUIDANCE** hint appears the first time each thing matters: moving on the board, events, casting, switching skills, parrying (the game briefly slows the first time his blade glows red), leaning, his death and learning, the Rite, adapting, stars, checkpoints, Crowns, and each new move a challenger brings.

## Your hands tell the story

At the start they are corrupted: black-violet skin, glowing red veins, thorns, an iron shackle with a broken chain, smoke, and claws that twitch. Every memory you restore purifies them. The skin warms, the veins turn gold then white, the thorns fall away, the shackle becomes a gold bracelet, the claws become nails, and smoke becomes motes of light.

## He rises above you

Each time he returns he is bigger and brighter, with an aura and rising motes. From the second fight on he descends into the hall through a pillar of light. Later challengers grow gold shoulder spikes and wings, and from the fourth they levitate. When he wins, he rises into the air.

## The loop

```
BOARD: walk the tiles
  story (narration, +2 Crowns) · event (choose a fate) · treasure · class altar (half-price class)
  → DEMON square → arena fights, with the Throne of Thought between his deaths
      0 stars  → NOT YET WORTHY: retry from your last checkpoint (every 3 fights)
      1+ stars → he ascends → Crown tally → MEMORY RESTORED + relic → fog lifts on the next region
after the sixth demon → the ending (and a new cycle that keeps Crowns, classes and Eternity)
```

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

- `scripts/board.gd`: the tabletop board, the King's piece, tiles, fog, region landmarks and camera
- `scripts/story.gd`: **all story content**: chapters, tile texts, choice events, memories, relics and the ending. Edit this file to rewrite the story.
- `scripts/main.gd`: world, HUD, board flow and tile events, fight loop, parry resolution, checkpoint/try-again, prestige flow, autoplay bot
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

The bot plays the boss: it aims, casts, parries ~65% of blows, pulls rites and buys upgrades. Extra flags:
- `--passive`: the bot never attacks, which exercises TRY AGAIN
- `--pure`: show the fully purified hands
- `--preview-board`, `--preview-throne`, `--preview-rite`, `--preview-heroes`, `--preview-prestige`: jump straight to a screen for screenshots

Last full run: the board walked end to end, Remembrance at every chapter, all 6 challengers, and the bot outlasted 15 / 14 / 10 / 8 / 6 / 6 of their lives (★★★ down to ★), 0 script errors.
