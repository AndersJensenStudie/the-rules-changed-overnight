# Hourglass pickup — implementation plan

In space mode, hourglasses float above or below some obstacles. They play their sand animation, flip over, and repeat. Picking one up slows the world down for 5 seconds and slows the music with it. Then the game returns to the starting speed.

## Decisions (from Q&A)

| Topic | Decision |
|---|---|
| Where | Space mode only. 1 in 10 obstacles gets an hourglass hovering above or below it. |
| Slow speed | 120 px/s, 60% of the starting speed of 200. |
| What slows | The world: ground, obstacles, lasers, and the alien's hovering and warning flashes. The player's jump and fall stay at normal speed, so dodging gets easier. |
| Music | Plays at 70% speed, which also lowers the pitch, like a tape slowing down. It slides down and back up smoothly. The ambient layer slows too. |
| After 5 s | The world returns to the starting speed (200), the music returns to normal, and normal acceleration continues from there. |

## Asset

| Asset | Facts | Use |
|---|---|---|
| `assets/images/hourglass.png` | 128×128, a 4×4 grid of 32×32 frames, 16 frames of sand running from the top half to the bottom. The hourglass spans x 8–20, y 5–23 in each frame (about 13×19 px). | `assets/animations/hourglass_frames.tres`, a non-looping `default` animation. |

## Animation loop: play, flip, play

Turned 180°, the last frame (sand at the bottom) looks the same as the first frame (sand at the top). So the loop is:

1. Play frames 1→16 once, at rotation 0°.
2. Turn the sprite from 0° to 180° (about 0.3 s) while it shows the last frame.
3. Snap back to rotation 0° and frame 1 in the same instant. They look identical, so the flip appears continuous.
4. Repeat from step 1.

## Steps

### 1. Hourglass pickup (`hourglass.tscn` + `hourglass.gd`)
- `hourglass.gd` extends `coin.gd`, so it moves with the world and emits `collected` once when the player touches it, then disappears.
- The script adds the play → flip → play loop above, driven by the sprite's `animation_finished` signal and a tween for the flip.
- Hitbox about 12×18, slightly inside the drawn hourglass.
- It gets the same dark outline node as the other sprites, so it stands out on the space backdrop.

### 2. Spawning (`cactus_spawner.gd`)
- New settings: `hourglass_scene`, `hourglass_chance` (0.1) and `hourglass_margin` (gap between the hourglass and the obstacle).
- After `_spawn_asteroids()` places a group, roll `hourglass_chance`. On success, place an hourglass at the group's center x:
  - **Above** the group (its top edge minus a margin). Always possible; it's kept at least 30 px below the top of the screen.
  - **Below** the group, only if there's room above the ground. For example, under a floating asteroid the spaceman can run through and grab it. A ground asteroid has no room below it.
  - Pick randomly among the options that fit.
- The spawner also gets `obstacle_spawned`-style forwarding for `hourglass_collected`, like coins.

### 3. World slowdown (`main.gd`)
- New settings: `slow_speed` (120), `slow_duration` (5 s), `slow_ramp_time` (0.4 s, how quickly the speed slides down and back up), `slow_music_scale` (0.7).
- `_on_hourglass_collected()` starts or extends the slowdown: `_slow_time = slow_duration`. Picking up another one while slowed resets the 5 s.
- While `_slow_time > 0`: no acceleration; `speed` slides toward `slow_speed` within the ramp time.
- When it runs out, `speed` slides back up to `start_speed` (not the speed before the pickup), and then normal acceleration resumes.
- `world_time_scale` (1.0 normally, down to 0.6 while slowed) follows the speed and is passed to the spawner as `spawner.world_time_scale`, for the things that don't scroll with the ground.
- The music's speed follows the same ramp via `Music.set_speed_scale()`, from 1.0 down to 0.7.

### 4. Lasers and the alien follow the slowdown
- `laser.gd`: moves at `laser_speed × spawner.world_time_scale`.
- `ufo.gd`: hovering advances by `delta × world_time_scale`, and the flash timers last `flash_time / world_time_scale`. So the warning stays the same length relative to the slower world.

### 5. Music (`music.gd`)
- `set_speed_scale(scale)` sets `pitch_scale` on both the music and the ambient player.
- `main._ready()` resets it to 1.0 on every run, because the `Music` autoload survives restarts. `_game_over()` resets it too, so the game-over screen never plays slowed music.

### 6. Revive and mode switches
- **Revive:** a revive freezes the world by setting speed to 0 and restores it afterwards. The slowdown timer only counts down while running, so a revive in the middle doesn't use up slow time.
- **Mode switch:** the world speed is shared across modes, so leaving space mode mid-slowdown keeps the slowdown until its 5 s are up. Only spawning is limited to space mode.

### 7. Verify
1. **Animation:** frames 1→16 play once, the sprite turns to 180°, then snaps back to 0° and frame 1, and the loop repeats.
2. **Spawning:**
   - about 10% of space-mode obstacles get an hourglass; none in other modes
   - positions are above or below and always on screen
   - the hourglass never sits inside an asteroid
3. **Pickup:**
   - speed slides to 120 within about 0.4 s and stays there for 5 s
   - music speed goes to 0.7
   - lasers fly at 60% speed
   - afterwards speed returns to 200, music to 1.0, and acceleration resumes
4. **Second pickup** while slowed extends the slowdown to 5 s from that moment.
5. **Game over during a slowdown** resets the music to normal. A restart starts at normal speed and music.
6. **Regression:** the existing space-mode tests still pass (lasers at normal speed, the alien's attack timing, asteroid bots), along with the other modes' bots.
7. **Renders:** the hourglass flip and its placement above and below asteroids.

## Files

| File | Change |
|---|---|
| new `hourglass.tscn`, `hourglass.gd`, `assets/animations/hourglass_frames.tres` | pickup with the play/flip loop |
| `cactus_spawner.gd` | hourglass spawning in space mode, `hourglass_collected`, `world_time_scale` |
| `main.gd` | slowdown timer, speed ramp, music scaling, resets |
| `music.gd` | `set_speed_scale()` |
| `laser.gd`, `ufo.gd` | follow `world_time_scale` |

Code follows the project's current style: no comments.
