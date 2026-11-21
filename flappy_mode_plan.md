# Flappy mode — implementation plan

A fourth game mode in the style of Flappy Bird. The player becomes a flying bird that flaps on every jump press, anywhere in the air. The ground kills, and the obstacles are pairs of Mario pipes, one hanging from the top and one standing on the ground, with a gap to fly through. Jumping over a moon can roll into this mode like any other.

## Decisions (from Q&A)

| Topic | Decision |
|---|---|
| Entering the mode | After the moon jump-over that switches into flappy mode, the bird hovers in place (no gravity) for 0.5 s. A flap during the hover ends it early. |
| Flapping | Allowed anytime, in the air or not. Each press sets an upward speed. No jump buffer, coyote time or jump-cut in this mode. |
| Tilt | Each flap snaps the bird nose-up (counter-clockwise). While falling it gradually tilts clockwise toward nose-down, like Flappy Bird. |
| Ground | Deadly. Touching it is a game over. |
| Ceiling | Solid but not deadly. The bird bumps against the top of the screen. |
| Pipes | A pair per obstacle: one flipped, hanging from the top; one upright from the ground. Any contact kills, including the lower pipe's top. |
| Hitbox | The bird's body only. The legs hang below it and don't count. |
| Moons | Float at a random height in this mode, so flying over (switch mode) or under (stay) is a real choice. |
| Sounds | Flap sounds from a new folder (placeholders). Pipe hits play `pipe_hit.wav`; death sounds are the dino game's. |

## Assets

| Asset | Facts | Use |
|---|---|---|
| `assets/images/flappers.png` | 64×96, 2×3 grid of 32×32 frames, 6 frames (bird with walking legs). Body spans x 8–28, y 9–21 in each frame; legs y 22–27. | `fly` animation (6 frames, about 10 fps) + the shared blood-splatter `die`. |
| `pipe.png` | as in Mario mode | Upright and flipped pipes. |
| `assets/sounds/pipe_hit.wav` | already used for pipe hits | Pipe hits, via the pipe's existing `hit_sound`. |
| `assets/sounds/death/` | dino death sounds | Death sounds; the default `death_sounds_dir`. |

**Placeholders to create** (copies, replaceable later without code changes):

| New file | Copy of | Purpose |
|---|---|---|
| `assets/sounds/flappy_flap/hop.wav` | `assets/sounds/jump_sounds/hop.wav` | Flap sound |
| `assets/sounds/flappy_flap/ho.wav` | `assets/sounds/jump_sounds/ho.wav` | Flap sound |

**Not specified; placeholders to confirm:**
- **Backdrop:** reuse the dino game's animated sky (`dino_backdrop_frames.tres`), which suits a flying bird.
- **Music:** reuse `basic.wav`.
- **Text and ground colors:** the dino game's grays.

## New mode settings

`mode_settings.gd` gets a **Flight** group. All of it defaults to off or unchanged, so the three existing modes behave exactly as now.

| Setting | Flappy value (first guess) | Meaning |
|---|---|---|
| `flight` | `true` | Flap-anywhere physics in place of the ground jump |
| `flap_velocity` | 190 px/s | Upward speed set by each flap |
| `flight_gravity` | 700 px/s² | Downward acceleration |
| `max_fall_speed` | 300 px/s | Fall speed cap |
| `floor_kills` | `true` | Touching the ground is a game over |
| `entry_hover_time` | 0.5 s | No-gravity hover when the mode starts |
| `flap_tilt_degrees` | −25° | Rotation snapped to on each flap |
| `dive_tilt_degrees` | 70° | Maximum nose-down rotation |
| `dive_tilt_speed` | 200°/s | How fast it tilts nose-down while falling |
| `night_y_range` | 60–180 px | Moon height range in this mode (other modes keep 200–200) |

Plus a new obstacle type, `PIPE_PAIRS`, alongside `CACTI`, `ASTEROIDS` and `PIPES`.

## Steps

### 1. Bird animation and settings file
- `assets/animations/flappy_frames.tres`: looping `fly` animation from the 6 frames, plus a copy of the shared blood-splatter `die`.
- **The animation name differs from `walk`:** the player plays an animation called `walk` today. `run()` and `apply_mode()` will play a `run_animation` named in the settings (`walk` for the existing modes, `fly` here) instead of the hard-coded `walk`.
- `assets/modes/flappy.tres` with the values above:
  - hitbox about 18×11 (the 21×13 body slightly inset)
  - flap sounds from `flappy_flap/`, death sounds from the default `death/` folder
  - obstacles `PIPE_PAIRS`, gaps about 1.2–1.8 s
- **Sprite placement:** `player.gd` places the hitbox with its bottom on the feet line (y 15). So `sprite_position` puts the bird's body over that 18×11 box, and the legs hang about 6 px below it. That's why dying on the ground shows the legs slightly in the ground.
- Add `flappy.tres` to the `modes` list in `main.gd`. Moon rolls then pick from three other modes.

### 2. Flight physics and tilt (`player.gd`)
- **Flight on (`mode.flight`):**
  - every `jump` press sets `velocity.y = -flap_velocity`, plays a flap sound and snaps `sprite.rotation` to `flap_tilt_degrees`
  - gravity is `flight_gravity`, capped at `max_fall_speed`
  - while falling, rotation moves toward `dive_tilt_degrees` at `dive_tilt_speed`
- **Only the sprite rotates.** The hitbox stays an upright rectangle. The outline copies are children of the sprite, so they rotate with it.
- **Hover:** a `hover_time` timer, started by `apply_mode()` when entering a flight mode. While it runs, `velocity.y = 0` and gravity is skipped. A flap ends it.
- **Ground death:** when `mode.floor_kills` and `is_on_floor()` while not invincible, emit a new `hit_ground` signal. `main.gd` connects it to `_game_over()` with no obstacle, so no hit sound plays, just the death sound.
- **Leaving flight mode:** `apply_mode()` with `flight` off resets `sprite.rotation` to 0 and cancels the hover. Normal gravity takes over mid-air.
- **Ceiling:** the existing stage boundary at y 12 already stops the bird, so nothing new is needed.

### 3. Revive in flappy mode (`main.gd`)
A +1 HP revive after hitting the ground would leave the bird sitting on the deadly floor. After the reverse death animation, a flight mode also restarts the 0.5 s hover, on top of the usual 1.5 s invincibility, so the player has time to flap away. Ground kills are ignored while invincible, as hits already are.

### 4. Pipe pairs (`pipe.gd`, `cactus_spawner.gd`)
- **`pipe.gd` gets two settings:**
  - **`flipped`:** builds the pipe hanging down from the top of the screen, with sprites mirrored with `flip_v` and positions mirrored in code. This avoids flipping a physics body with negative scale, which Godot handles badly.
  - **`solid_top`:** when off, the one-way top surface isn't created, and the kill area covers the whole lip including its top edge.
  - Mario mode keeps the defaults (upright, solid top), so it's unchanged.
- **`_spawn_pipe_pair()`:** spawns an upright pipe from the floor and a flipped pipe from the top of the screen at the same x, both with `solid_top = false`.
  - **Gap:** `pipe_pair_gap` px tall, about 70 to start (the bird's hitbox is 11 px tall).
  - **Gap center:** random within `pipe_pair_center_range`, but within `pipe_pair_max_shift` px of the previous gap, so consecutive gaps are always reachable with flaps.
  - **Height limits:** each pipe is at least the lip height, so it never draws inverted or empty.
- No coins or mushrooms in this mode.

### 5. Moons at random heights (`cactus_spawner.gd`)
`_spawn_night()` uses `randf_range(mode.night_y_range.x, mode.night_y_range.y)` in place of the fixed `night_y`. The moon's pass zone already reaches from its top edge past the ceiling at any height, so detecting "over" keeps working. The other modes keep 200–200, unchanged.

### 6. Flap sounds
Create `assets/sounds/flappy_flap/` with the two placeholder copies. The player's per-folder sound cache picks them up through `jump_sounds_dir` with no code change.

### 7. Verify
Headless and in a real window, as before, since collision timing has only shown up in windowed runs.

1. **Regression:** the existing tests behave the same, since the Flight settings default to off and moons keep 200 in other modes. That covers the cactus bot, moon under/over/hit, the Mario pipe sweep, the three-mode bot, revive, scoring and the outline sync.
2. **Entering flappy:** after the moon switch the bird holds its height for 0.5 s (y changes less than 1 px), then falls. A flap during the hover rises immediately.
3. **Flight:**
   - flaps work at any height, including mid-air repeats
   - each flap snaps the rotation to −25°, and it tilts toward +70° while falling
   - the ceiling stops the bird without killing it
4. **Ground** kills: death sound only, no hit sound.
5. **Pipes:**
   - the upper pipe, lower pipe and lower pipe's top all kill and play `pipe_hit.wav`
   - flying through the gap is safe
   - the legs dangling below the gap edge don't count as a hit
6. **Playability:** a bot that flaps to stay near the next gap's center survives 25 s at speeds 200, 260 and 320. Tune the gap, shift, gaps-in-time and flap numbers until it does.
7. **Moons:**
   - flying over one switches mode; flying under keeps flappy mode
   - moon heights span the configured range
8. **Revive** in flappy mode, after both a ground hit and a pipe hit, gives the hover plus invincibility and the run continues.
9. **Leaving flappy** mid-air: rotation resets, normal gravity, and the dino, spaceman or Mario lands normally.
10. **Renders:** the bird's tilt, the pipe pairs with the flipped top pipe, and the hitbox drawn over the body only.

## Files

| File | Change |
|---|---|
| `mode_settings.gd` | Flight group, `run_animation`, `night_y_range`, `PIPE_PAIRS` |
| `player.gd` | flight physics, tilt, hover, `hit_ground` signal, `run_animation` |
| `main.gd` | `flappy.tres` in `modes`, ground-death hook, hover on revive |
| `pipe.gd` | `flipped` and `solid_top` settings |
| `cactus_spawner.gd` | `_spawn_pipe_pair()`, moon height from `night_y_range` |
| new `assets/modes/flappy.tres` | flappy settings |
| new `assets/animations/flappy_frames.tres` | `fly` + `die` |
| new `assets/sounds/flappy_flap/` | placeholder flap sounds |

Code follows the project's current style: no comments.

## Open points to confirm while building
- Flap, gravity, gap size and pipe spacing numbers are first guesses, tuned with the bot and by playing.
- Backdrop, music and colors are placeholders (dino sky, `basic.wav`).
- A moon floating high in the air could overlap a following pipe pair. The moon is its own spawn with normal gaps on both sides, so they shouldn't overlap; check in the renders.
