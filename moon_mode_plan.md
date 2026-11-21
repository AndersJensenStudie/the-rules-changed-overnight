# Moon mode — implementation plan

Jumping **over** a moon switches the run into *moon mode*. In moon mode, gravity is lower, the dino becomes a spaceman, asteroids replace cacti, and a space backdrop with its own music plays. Dying in moon mode shows the normal game over. Pressing SPACE restarts in the normal dino game.

## Decisions (from Q&A)

| Topic | Decision |
|---|---|
| Death in moon mode | Normal game over (death sound, GAME OVER text). SPACE restarts as the dino. |
| Asteroid placement | Mix: some on the ground, some floating at heights you can run under or jump over. |
| Gravity | Higher and slower jump: about 1.6× the height (84 → 135 px) and about 2.5× the airtime. |
| Visuals | `assets/images/backdrops/bg-space.png` shown behind the game. |
| Sound | Music switches from `basic.wav` to `assets/music/chorus.wav`. `assets/sounds/ambient/ambient.wav` loops underneath. |

## Assets on hand

| Asset | Facts | Use |
|---|---|---|
| `assets/images/Spaceman.png` | 96×128, 3×4 grid of 32×32 frames, 12-frame walk cycle. Figure spans x 7–24, y 2–29 in the frame. | New `walk` animation. |
| `assets/images/asteriods/astroid1-4.png` | 32×32 each, irregular shapes (about 16–25 px wide, 16–22 px tall). | Random texture per asteroid. |
| `assets/images/backdrops/bg-space.png` | 1254×1254 RGB. | Scaled down to fit the 250×250 view (scale 0.2). |
| `assets/music/chorus.wav` | 13.0 s stereo, same length as `basic.wav`. | Moon-mode music. Swapped in at the same playback position. |
| `assets/sounds/ambient/ambient.wav` | 26.1 s mono, quiet (peak −20 dBFS). | Looping layer under the music. Needs a volume boost. |

## Architecture

`main.gd` gets a `mode` (`EARTH` / `MOON`) alongside the existing `state`. One function, `enter_moon_mode()`, tells each part of the game to switch. Each part owns its own moon settings, so `main.gd` stays small.

```
night.tscn (PassZone) --passed_over--> CactusSpawner --moon_passed--> main.enter_moon_mode()
																		├─ player.set_moon(true)
																		├─ spawner.set_moon(true)
																		├─ ground.set_moon(true)
																		├─ Backdrop fade-in
																		└─ Music.set_moon(true)
main._ready() (every restart) ──> Music.set_moon(false)
```

Restarting reloads `main.tscn`, which resets the player, spawner, ground and backdrop to Earth automatically. Only the `Music` autoload survives a reload, so `main._ready()` must reset it explicitly.

## Steps

### 1. Detect passing above a moon (`night.tscn`, `obstacle.gd`)
- Add a child `Area2D` called `PassZone` to `night.tscn`. Its rectangle covers the moon's width (x −12…15) from the moon's top edge (y −13) up past the ceiling (the stage ceiling is at world y 12).
- Because the zone sits only *above* the moon, running under it never enters the zone.
- On `PassZone.body_exited(player)`, wait one physics frame (`call_deferred` or `await get_tree().physics_frame`) so a hit on the same frame takes priority. Then emit `passed_over` if the game is still running.
  - The only ways out of the zone are the side, as the moon scrolls past, or the bottom, which means touching the moon and dying first. So "exited and still alive" means "passed above".
- Put the `passed_over` signal in a small `night.gd` that extends `obstacle.gd`, so cacti and asteroids don't carry it.
- `cactus_spawner.gd` connects `passed_over` to a new `moon_passed` signal when it spawns a moon, the same way it forwards `hit`. `main.gd` connects `moon_passed` to `enter_moon_mode()`.
- Guard: ignore the signal unless `state == RUNNING and mode == EARTH`.

### 2. Player: gravity, sprite and hitbox (`player.gd`, new `assets/animations/spaceman_frames.tres`)
- Turn the three `@onready` jump values into a `_recalc_jump()` function. Call it from `_ready()` and `set_moon()`.
- Add moon settings: `moon_jump_height := 135.0`, `moon_time_to_peak := 0.6`, `moon_time_to_fall := 0.65`, for about 1.25 s airtime versus 0.51 s now. At the peak, the head is at world y 81, well below the ceiling at 12. `jump_cut`, coyote time and jump buffer stay as they are.
- Switching mid-air is fine. The switch happens while the player is coming down from the moon jump, so the new low gravity takes over immediately and lands softly. That works as the "entering low gravity" moment.
- Create `spaceman_frames.tres` with a 12-frame looping `walk` from `Spaceman.png`.
  - Copy in the existing `die` animation (the blood splatter) so `die()` works unchanged.
  - Set the walk speed to about 8 fps. Twelve frames at the dino's 5 fps would look sluggish. Tune by eye.
- `set_moon(on)`:
  - Swap `$AnimatedSprite2D.sprite_frames` and keep the animation playing.
  - Adjust the sprite offset so the feet line up. The spaceman's feet are at frame y 29, the dino's at 32, so shift it 3 px down.
  - Swap the collision shape to fit the spaceman, about 10×26 instead of 24×26, keeping the bottom edge on the floor.
  - Change the shape's `size` on a duplicated shape, not the shared one (`shape = shape.duplicate()` once in `_ready`).
- Jump and death sounds are unchanged.

### 3. Asteroids (new `asteroid.tscn` + `asteroid.gd`)
- `asteroid.gd` extends `obstacle.gd`, so it moves and emits `hit` the same way.
- In `_ready()`, pick a random texture from `res://assets/images/asteriods`, using `ResourceLoader.list_directory` like the sound loader, so new images are picked up automatically.
- Build the hitbox from the chosen texture's alpha:
  - `BitMap.create_from_image_alpha()` → `opaque_to_polygons()` → one `CollisionPolygon2D` per polygon, offset by −16,−16 to match the centered sprite.
  - Shrink the polygon by about 1 px (`Geometry2D.offset_polygon(poly, -1)`) so grazing a corner doesn't kill.
  - The hitbox then always matches whichever asteroid image is used, including ones added later.
- Cache the textures and their polygons in a static dictionary so each image is only processed once.

### 4. Spawner in moon mode (`cactus_spawner.gd`)
- Add `set_moon(on)` and a set of `moon_*` settings:
  - No moons spawn in moon mode.
  - `_spawn_group()` spawns asteroids in groups of 1–2.
  - Heights, picked at random per group:
    - **Ground**, about 50%: bottom on the floor, same as cacti. Must be jumped.
    - **Low air**, about 30%: bottom 2 px above the standing head, like the moon (world y ≈ 214 for the bottom edge). Run under it, or jump over it.
    - **High air**, about 20%: floats at roughly 90–110 px above the ground. Harmless unless you take a full-height jump at the wrong moment, which rewards short hops.
  - Wider gaps to fit the longer airtime: `moon_min_gap_seconds := 1.4`, `moon_max_gap_seconds := 2.4`. These are first guesses; verify them with the test bot (step 8).
- Cacti already on screen when the mode switches keep scrolling off. New spawns are asteroids. That avoids things popping out of existence.

### 5. Backdrop and ground (`main.tscn`, `ground.gd`)
- Add a `Backdrop` `Sprite2D` to `main.tscn` as the first child, so it draws behind everything:
  - `bg-space.png`, `centered = false`, `scale = Vector2(0.2, 0.2)` (1254 × 0.2 ≈ 251 px).
  - Starts with `visible = false`.
- `enter_moon_mode()` fades it in by tweening `modulate.a` from 0 to 1 over about 0.3 s.
- `ground.gd` gets `set_moon(on)`, which switches the line color to a light gray so it stays visible on the dark backdrop.
- The HUD message color in `main.gd` also switches to light gray in moon mode, so GAME OVER is readable.

### 6. Music (`music.gd`, import settings)
- Set `edit/loop_mode=2` (forward loop) in `chorus.wav.import` and `ambient.wav.import`, as was done for `basic.wav`.
- `music.gd` gets a second `AudioStreamPlayer` for the ambient layer, and `set_moon(on)`:
  - Remember `get_playback_position()`, swap the stream to chorus or basic, and `play(position)`. Both tracks are 13.0 s, so the music continues seamlessly.
  - Start or stop the ambient player. Ambient is very quiet (−20 dBFS peak), so start it at about +10 dB and tune by ear.
  - Calling it with the current mode does nothing, so `main._ready()` can call `Music.set_moon(false)` on every restart without a hiccup.

### 7. Game flow (`main.gd`)
- `enum Mode { EARTH, MOON }`, `var mode := Mode.EARTH`.
- `enter_moon_mode()`: apply the guard from step 1, set `mode = MOON`, then call the `set_moon(true)` functions plus the backdrop fade and music switch.
- Speed and acceleration carry on unchanged. The switch only happens at speed 200 or above, because moons only spawn there.
- Death in moon mode uses the existing `_game_over()`. The spaceman plays the splatter animation on the space backdrop and GAME OVER shows. SPACE reloads the scene in Earth mode, and `_ready()` resets the music.

### 8. Verify (headless Godot bot scripts, as used so far)
1. **Run under a moon:** the game stays in Earth mode.
2. **Jump over a moon:** moon mode starts. Check that the spaceman frames are in use, the gravity values changed, the backdrop is visible, `Music` is playing chorus with ambient underneath, and the next spawns are asteroids.
3. **Hit a moon:** game over, no switch to moon mode. This checks that a hit wins over the pass signal.
4. **Die in moon mode:** game over, then restart. Check Earth mode, dino frames, `basic.wav` music and no ambient.
5. **Jumpability sweep in moon gravity:** a bot that jumps at the right time survives 25 s at speeds 200, 260 and 320, for each height band. Tune the gaps and band heights until it does.
6. **No moons spawn while in moon mode.**
7. **Regression:** the existing cactus bot and moon under/over sweep still pass in Earth mode.

## Files

| File | Change |
|---|---|
| `night.tscn`, new `night.gd` | `PassZone` area + `passed_over` signal |
| `player.gd` | `_recalc_jump()`, moon gravity settings, `set_moon()` |
| `assets/animations/spaceman_frames.tres` | new: spaceman `walk` (12 frames) + `die` |
| new `asteroid.tscn`, `asteroid.gd` | random texture, hitbox built from the image |
| `cactus_spawner.gd` | `moon_passed` signal, `set_moon()`, asteroid spawning with height bands |
| `ground.gd` | `set_moon()` line color |
| `main.tscn`, `main.gd` | `Backdrop`, `mode`, `enter_moon_mode()`, music reset in `_ready()` |
| `music.gd`, `chorus.wav.import`, `ambient.wav.import` | moon music + ambient layer, looping |

Code follows the project's current style: no comments.

## Assumptions to confirm while building
- `chorus.wav` is a variant of the `basic.wav` tune, so swapping at the same position sounds right. If it isn't, start chorus from 0 instead.
- The moon look (spaceman, backdrop, chorus) stays on during the game-over screen and only reverts when you restart.
- The asteroid folder keeps its current spelling, `asteriods`. Renaming it to `asteroids` is a one-line path change if wanted.
- The spaceman's hitbox is narrower than the dino's (about 10 px vs 24 px), which makes moon mode a little more forgiving on the ground. The low-gravity jump and floating asteroids should make up for it; check while tuning.
