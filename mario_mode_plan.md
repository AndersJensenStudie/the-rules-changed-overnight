# Mario mode — implementation plan

A third game mode alongside the dino game (Earth) and moon mode. Jumping **over** a moon now switches to one of the two *other* modes at random. Mario mode has its own player sprite, solid pipes you can stand on, coins to collect, its own jump sounds, a backdrop and music.

## Decisions (from Q&A)

| Topic | Decision |
|---|---|
| Moon jump-over | Switch to a random mode, picked from the two you're **not** in, so every clear changes the mode. |
| Pipe size | Drawn at 2×, about 22 px wide at the lip. The body stretches to random heights, about 30–60 px total. |
| Jump feel | Higher and a bit floaty: about 110 px high (dino: 84), with a little more hang time. |
| Coins | Float above some pipes (a reward for jumping on them), and in short arcs between pipes that a normal jump passes through. |
| Coin count | `coins` variable in `main.gd`, counted per run (reset on restart), kept across mode switches. Not shown on screen yet. |
| Death | Same as other modes: game over, SPACE restarts in the dino game. |

## Assets

| Asset | Facts | Use |
|---|---|---|
| `assets/images/mario.png` | 96×96, 3×3 grid of 32×32 frames, 8 running frames (last cell empty). Figure spans about x 8–28, y 5–24 in the frame, so its feet sit 7 px higher than the dino's. | `walk` animation (8 frames, ~10 fps) + the existing blood-splatter `die`. |
| `assets/images/pipe.png` | 32×32. Lip: rows 14–16, x 11–21 (11 px wide). Body: rows 17–30, x 13–19 (7 px wide). Rows 18–29 are identical. | Lip drawn once; middle body rows stretched to the wanted height. All at 2× scale. |
| `assets/images/coin.png` | 32×32, coin spans x 3–30, y 8–24 (28×17 px). | Drawn at 0.5× (about 14×9 px). |
| `assets/music/bass_boost.wav` | 12.96 s stereo (the other tracks are 13.0 s). | Mario-mode music, switched in at the same song position. Needs `loop_mode=2`. |

**Placeholders to create** (copies, so the real files can replace them later without code changes):

| New file | Copy of | Purpose |
|---|---|---|
| `assets/sounds/mario_jump/yau.wav` | `assets/sounds/jump_sounds/yau.wav` | Mario-mode jump sounds. More files can be dropped in later. |
| `assets/sounds/coin/coin.wav` | `assets/sounds/jump_sounds/jump.wav` (short, 0.17 s) | Coin pickup sound. |
| `assets/images/backdrops/bg-mario.png` | `assets/images/backdrops/bg-space.png` | Mario-mode backdrop. |

## Architecture: from `set_moon(bool)` to mode settings

Moon mode was built as an on/off switch (`set_moon(true/false)` on the player, spawner, ground and music). A third mode doesn't fit a boolean, so the first step is a refactor to **mode settings resources**. Each mode becomes one `.tres` file that holds everything that differs between modes. Adding a fourth mode later then means adding one more `.tres`, not more code.

**New `mode_settings.gd`** (`class_name ModeSettings extends Resource`):

| Group | Settings |
|---|---|
| Jump | `jump_height`, `time_to_peak`, `time_to_fall` |
| Player | `sprite_frames`, `sprite_position`, `hitbox_size`, `jump_sounds_dir` |
| Obstacles | `obstacles` (enum `CACTI`, `ASTEROIDS`, `PIPES`) |
| Look | `backdrop` (texture or none), `ground_color`, `label_color` |
| Sound | `music`, `ambient` (stream or none) |

**Three settings files** in `assets/modes/`:

| File | Values |
|---|---|
| `earth.tres` | today's dino values (84 px / 0.25 s / 0.26 s, dino frames, cacti, no backdrop, `basic.wav`) |
| `moon.tres` | today's moon values (135 px / 0.6 / 0.65, spaceman, asteroids, `bg-space.png`, `chorus.wav` + `ambient.wav`) |
| `mario.tres` | new values: about 110 px / 0.32 / 0.30, Mario frames, pipes, `bg-mario.png`, `bass_boost.wav`, `mario_jump/` sounds |

Each part of the game gets `apply_mode(settings: ModeSettings)` in place of `set_moon(on)`:

```
main.gd: modes = [earth, moon, mario], current index
  moon passed ──> pick a random mode != current ──> _set_mode(i)
                                                     ├─ player.apply_mode(s)
                                                     ├─ spawner.apply_mode(s)
                                                     ├─ ground.apply_mode(s)
                                                     ├─ backdrop swap/fade
                                                     └─ Music.apply_mode(s)
  main._ready() ──> _set_mode(EARTH) without fades (Music survives scene reloads)
```

## Steps

### 1. Refactor to mode settings (no behavior change)
- Create `mode_settings.gd` and `assets/modes/earth.tres` and `moon.tres` with the values currently hard-coded as `moon_*` settings in `player.gd`, `cactus_spawner.gd`, `ground.gd`, `music.gd` and `main.gd`.
- Replace each `set_moon(on)` with `apply_mode(settings)`, and remove the old `moon_*` settings.
- `main.gd`: replace `enum Mode { EARTH, MOON }` with an exported `modes: Array[ModeSettings]` and a `mode_index`.
- **The player's hitbox keeps its bottom on the floor** for any hitbox height: `hitbox.position.y = 15 - size.y / 2` (15 is the feet line). Moon mode got away without this because both hitboxes were 26 px tall; Mario's is shorter (about 14×19).
- **Check:** all existing tests (cactus bot, moon under/over/hit, Earth ↔ moon toggle bot, restart) must pass unchanged before anything new is added.

### 2. Moon picks a random other mode (`main.gd`)
- `_on_moon_passed()`: build the list of indices except `mode_index`, call `pick_random()`, then `_set_mode()`.
- The existing guards stay: a moon counts once (`night.gd`), and switches only happen while running.

### 3. Mario player assets
- Create `assets/animations/mario_frames.tres`: a looping `walk` with the 8 frames from `mario.png` at about 10 fps, plus a copy of the blood-splatter `die`, as `spaceman_frames.tres` does.
- `sprite_position` for Mario: the frame is centered, so shift it so the feet (frame row 24) land on the feet line, about 7 px lower than the dino. Confirm with a render.
- Create the `mario_jump/` placeholder folder.
- **The player loads jump sounds per folder**, cached in a dictionary so each folder is only loaded once. `apply_mode` switches which list is used.

### 4. Pipes (new `pipe.tscn` + `pipe.gd`)
A pipe is a solid platform on top and deadly on the sides:

```
Pipe (Area2D, pipe.gd extends obstacle.gd)  ← kill area: hit on side contact
├─ LipShape (CollisionShape2D)              ← lip sides, starting 2 px below the top surface
├─ BodyShape (CollisionShape2D)             ← body sides, down to the floor
├─ Top (StaticBody2D)
│   └─ CollisionShape2D (one_way_collision) ← the surface you stand on; solid from above only
├─ Lip (Sprite2D, region = lip rows, scale 2)
└─ Body (Sprite2D, region = body rows, scale 2 × stretched height)
```

- `pipe.gd` has a `height` setting, set by the spawner before the pipe is added. `_ready()` sizes the shapes and sprites so the base sits on the floor (world y 242) and the lip is `height` px above it.
- **One-way collision** on `Top` means the player lands on it from above, while hitting it from the side passes through into the kill area. The kill area starts 2 px below the top surface, so standing on the pipe never touches it.
- The pipe moves by changing its position each frame, as cacti do. `Top` is a `StaticBody2D`, which reports no velocity, so the player is not dragged along. When the pipe scrolls out from under the player, they fall off.
- **Safety:** the player stores its starting x and resets to it after `move_and_slide()`, so platform contact can never move the player sideways.
- Areas that only react to the player (cacti, moons, asteroids, coins) already ignore other bodies, so the pipe's `StaticBody2D` doesn't trigger them.

### 5. Coins (new `coin.tscn` + `coin.gd`)
- `coin.gd` extends `obstacle.gd` for the movement. It overrides `_on_body_entered` to emit a `collected` signal and remove itself, instead of emitting `hit`.
- Sprite at 0.5× scale. Hitbox about 12×8, slightly smaller than the drawn coin.
- **The sound plays from `main.gd`, not the coin**, because the coin is removed the moment it's picked up: a `CoinSound` player on the `SFX` channel, using `assets/sounds/coin/coin.wav`.
- `main.gd`: `var coins := 0`. Each pickup does `coins += 1` and plays the sound.

### 6. Spawner in Mario mode (`cactus_spawner.gd`)
- `apply_mode()` stores the obstacle kind. `_spawn_group()` keeps the moon roll first (moons spawn in every mode), then branches: cacti, asteroids or `_spawn_pipe()`.
- `_spawn_pipe()`: one pipe with a random height in `pipe_height_range` (about 30–60 px). Then, at random:
  - **About 50%:** a coin floating about 20 px above the pipe's lip, reachable from the pipe top or by a high jump.
  - **About 40%:** an arc of 3 coins in the following gap, placed along a normal jump's path, so jumping there collects them.
- Gaps get their own `pipe_min_gap_seconds` / `pipe_max_gap_seconds`, tuned with the test bot so a pipe and the next obstacle can always be handled with one jump, or a hop onto the pipe and off again.
- The spawner forwards `coin_collected` the same way it forwards `player_hit` and `moon_passed`.

### 7. Backdrop, ground, label, music
- **Backdrop:** `_set_mode` sets the backdrop texture from the mode's settings.
  - Hidden to shown: fade in, as now.
  - Shown to hidden: fade out.
  - Shown to shown (e.g. moon to Mario, currently the same placeholder image): swap the texture directly.
- **Ground and label colors:** from settings. Mario mode uses moon mode's light colors while its backdrop is the dark placeholder.
- **Music:** `Music.apply_mode(settings)` switches to the mode's track at the same playback position (wrapped to the new track's length), and starts or stops the ambient layer when the mode has one.
- Set `loop_mode=2` in `bass_boost.wav.import`.

### 8. Verify
Collision timing differs between headless and windowed runs (that's how the moon double-switch was found), so the pipe tests run **both headless and in a real window**.

1. **Regression** after the step 1 refactor: every existing test passes.
2. **Moon roll:** over many jump-overs, each mode switches only to one of the other two, and all pairs occur.
3. **Pipes:**
   - Landing on top works at every pipe height.
   - Running into the side, or clipping the lip's side, kills.
   - Riding a pipe until it scrolls away drops the player safely to the ground.
   - The player's x never drifts.
4. **Pipe jumpability:** a bot survives 25 s at speeds 200, 260 and 320 in Mario mode.
5. **Coins:** each coin counts once, the count survives mode switches and resets on restart, and the sound plays.
6. **Moon in Mario mode:** under, over and hit all behave, with Mario's shorter hitbox and higher jump.
7. **Renders:** Mario's feet on the ground and on pipe tops, pipe stretching at several heights, coin size.

## Files

| File | Change |
|---|---|
| new `mode_settings.gd`, `assets/modes/earth.tres`, `moon.tres`, `mario.tres` | per-mode settings |
| `main.gd` | modes array, random other-mode roll, `coins`, `CoinSound`, backdrop swap logic |
| `main.tscn` | `CoinSound` node, `modes` filled in |
| `player.gd` | `apply_mode()`, hitbox bottom kept on the floor, per-folder jump sound cache, fixed x |
| `cactus_spawner.gd` | `apply_mode()`, pipe + coin spawning, `coin_collected` signal |
| `ground.gd`, `music.gd` | `apply_mode()` |
| new `pipe.tscn`, `pipe.gd` | solid top, deadly sides, stretchable height |
| new `coin.tscn`, `coin.gd` | collectible |
| new `assets/animations/mario_frames.tres` | Mario walk + die |
| new placeholder copies | `mario_jump/yau.wav`, `coin/coin.wav`, `bg-mario.png` |
| `assets/music/bass_boost.wav.import` | loop on |

Code follows the project's current style: no comments.

## Open points to confirm while building
- Exact Mario jump numbers (about 110 px, 0.32 s up, 0.30 s down) and pipe gap timings are first guesses, tuned with the bots and by playing.
- Mario's hitbox (about 14×19) is shorter than the dino's, so the moon's 2 px under-clearance becomes about 9 px in Mario mode. Running under a moon stays easy; jumping over should be checked.
- Obstacles already on screen when the mode switches stay as they are until they scroll off, like leftover cacti today. A pipe left over after leaving Mario mode stays solid on top, so the dino or spaceman can still land on it.
