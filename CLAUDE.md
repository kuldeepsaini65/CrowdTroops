# CLAUDE.md — Gatecrush (3D crowd-runner shooter for Android)

This file gives Claude everything it needs to build this project. Read it fully before writing code, and keep it updated as decisions change.

---

## 1. What we are building

**Gatecrush** is a 3D mobile arcade game for Android, published on Google Play. The genre is the "crowd cannon" type, like Mob Control: the player slides a cannon left and right at the bottom of a road and holds to fire a stream of small blue soldiers forward. The soldiers pass through gates that multiply them (×2, ×3, +10). They clash 1-for-1 with the enemy red army, and whatever survives smashes into the enemy fort or boss.

All characters, names, art, UI and audio must be **original**. Do not copy Mob Control's assets, logos, UI layouts, text or character designs. The game mechanics themselves are fine to use.

**Target quality:** a polished, stylized 3D look, close to the reference image the owner provided (described in §4). It has to run smoothly (60 fps) on mid-range Android phones and be production ready for the Play Store.

---

## 2. Tech stack (decided)

| Item | Choice |
|---|---|
| Engine | **Godot 4.x, latest stable** (4.3 or newer). Use the standard build, not .NET. |
| Language | **GDScript** with static typing (`var x: int`, typed arrays, `-> void`) |
| Renderer | **Mobile** renderer (Vulkan), with Compatibility as a fallback option |
| Target | Android, arm64-v8a (plus armeabi-v7a if cheap). Output is an **.aab** for Play and an **.apk** for testing |
| Editor | VS Code with the godot-tools extension. Scenes are kept as text `.tscn`/`.tres` files |
| Version control | git, with a `.gitignore` for `.godot/`, `*.keystore`, `export_credentials.cfg`, `build/` |

**Reasons for Godot:** it is free with no royalties, its scenes and scripts are text files that are easy to edit from VS Code, it exports to Android natively, and `MultiMeshInstance3D` can draw thousands of units in one draw call.

---

## 3. Core gameplay (exact rules)

### 3.1 Layout
- The playfield is a straight **road lane**, about 8 m wide and 60 m long, running along −Z (away from the camera).
- The **cannon** is at the near end (z ≈ 0). The **enemy base/boss** is at the far end (z ≈ −55).
- The **camera** is a fixed perspective camera behind and above the cannon, looking down the road at about 55–60° pitch with FOV ~50. The whole lane must fit in portrait 9:16 and taller screens (9:19.5, 9:21). Add a gentle follow on X (lerp 10% toward cannon X) and support screen shake.

### 3.2 Controls
- Touch and drag horizontally anywhere: the cannon target X moves by drag delta × sensitivity (≈1.15 in world-units-per-screen-width terms, tunable). The cannon lerps to its target.
- While a finger is down, the cannon **auto-fires**. Releasing stops firing.
- Desktop testing: A/D or arrow keys to move, Space to fire, P to pause.

### 3.3 Units
- **Soldier (blue):** value 1, speed 7 m/s forward, with a small random lateral spread on spawn. After passing the last gate row, soldiers steer toward the base X.
- **Champion (gold, with a crown):** fired automatically every **26th shot**. Value = `6 + 3 × champ_upgrade`. Champions are not cloned by gates. A ×N gate multiplies the champion's value instead, and a +N gate adds to it. The champion's scale grows with √value.
- **Enemy grunt (red):** value 1, walks toward the player at ~2 m/s (rising with level), with a gentle sine-wave sway.
- **Enemy brute (dark red, horned, bigger):** value 5, slower. It appears from level 3 onwards with a 6–22% chance.
- **Combat:** when a friendly and an enemy overlap (sum of radii), both lose `min(a, b)` value. A unit at value 0 dies with a burst effect.
- **Damage:** a friendly reaching the base deals its value as damage. An enemy reaching the player's wall line removes its value from wall HP.

### 3.4 Gates
- Gates are glass panels with posts and a big floating label (`×2`, `×3`, `+7`). They slide left and right inside their lane range and bounce at the edges.
- Each unit can trigger each gate **only once**. Track this with a per-unit bitmask.
- When a ×N gate triggers, spawn N−1 clones near the unit, each with the same value and the same gate mask. When a +N gate triggers, spawn N clones.
- If the unit cap is reached, add the clone's value to the original unit instead of spawning, so the totals stay correct.
- Gate rows per level: level 1–2 have 1 row, level 3–6 have 2 rows, level 7+ have 3 rows. From level 4 onwards, a row may have 2 narrower gates moving in opposite directions. Gate speed = `min(115, 28 + 6 × level)` scaled to world units.
- Later-level variety (milestone 4): red "−N" gates, a rotating gate, gates mounted on a moving platform, and a breakable wooden barricade.

### 3.5 Enemy base and boss
- Levels 1–4 end in an **enemy fort** with HP = `round(70 + 38 × L + 3 × L²)`. A world-space HP bar sits above it. It spawns groups of 2–7 enemies every `max(0.5, 1.5 − 0.07 × L)` seconds (with ±30% jitter).
- **Every 5th level is a boss level**: a giant skeleton with an HP number floating over its head. It slowly advances and slams the ground every few seconds, killing units within a radius. It stands in front of a dense red army. Its HP scales the same way as the fort's, ×1.6.
- **Win** when base/boss HP ≤ 0. **Lose** when wall HP ≤ 0. Wall HP = `12 + 4 × wall_upgrade`.

### 3.6 Economy and progression
- Coins on a win = `25 + 8 × L + 2 × wall_hp_remaining`. On a loss = `round(damage_fraction × (12 + 4 × L))`.
- Upgrades, each up to level 12. Cost = `round(25 × 1.5^level)`.
  - Fire rate: interval = `max(0.045, 0.112 − 0.0058 × lvl)` seconds
  - Champion: value +3 per level
  - Wall: +4 HP per level
- Save `level`, `coins`, `upgrades` and `settings` to `user://save.json`. Write atomically (write a temp file, then rename).

### 3.7 Screens
1. **Splash/boot** → **Home**: big "PLAY" button with the current level, three upgrade cards, a settings cog, and a coin counter.
2. **In-game HUD**: level, wall HP, coins, a pause button, and a champion progress ring on the cannon.
3. **Pause**: resume, restart, home, sound and music toggles, vibration toggle.
4. **Win / Lose**: stats (units sent, peak crowd, raiders crushed, coins earned), then Continue. Later, an optional "×2 coins" rewarded-ad button.

---

## 4. Art direction (match the reference image)

The reference screenshot shows:
- A **desert canyon** world: warm orange sandstone, rocky cliffs with layered strata, scattered cacti and small rocks, and soft white fog or clouds filling a chasm.
- A grey **asphalt road** with a dashed white center line and light edge lines, lined by **wooden post-and-rail fences**.
- A **wooden plank bridge** with concrete abutments crossing the chasm in the middle of the level.
- A blue **wheeled cannon** at the bottom. The **blue army** is chunky glossy capsule soldiers with spiky heads. The **red army** is a dense blob of red soldiers at the far end.
- A **giant skeleton boss** holding a glowing, fiery hammer, with a bold white HP number ("1000") over its head.
- A **purple/blue glossy gate** sign reading "×3", and a bold white floating number showing the crowd count near the crowd.
- Lighting: a bright warm sun from the upper left, soft shadows, saturated colors, a slight bloom on the glowing items. It reads as stylized-realistic, like a high-end casual mobile game.

### Rendering setup
- `WorldEnvironment`: a sky with a warm horizon, filmic or ACES tonemap, subtle glow/bloom (only emissive items should bloom), SSAO off on mobile, fog subtle and warm.
- One `DirectionalLight3D` with shadows on: 2 cascades max, shadow distance ~70 m, and soft-shadow quality tuned for mobile.
- Toon-ish PBR materials: roughness 0.5–0.7, plus a slight rim light via a custom shader on the units so they pop against the road.
- Chasm fog: a few large billboard cloud sprites with soft alpha, or a `FogVolume` if performance allows.
- Particles: `GPUParticles3D` for impacts, gate flashes, the champion trail, boss hammer embers and fort destruction. Fall back to `CPUParticles3D` on the Compatibility renderer.
- UI: bold rounded display font (e.g. "Lilita One" or "Luckiest Guy" from Google Fonts, both OFL), white text with a thick dark outline, chunky glossy buttons.

### 3D asset sources (commercial-use-safe)
Use only assets whose license allows commercial use. Record every asset in `ASSETS_LICENSES.md` (name, author, URL, license).
- **Kenney.nl** (CC0): Nature Kit, Desert/Western kits, Tower Defense Kit, Blaster Kit, Particle Pack, UI Pack.
- **Quaternius** (CC0): Ultimate Monsters, Animated Skeleton, Stylized Nature, Animated Characters.
- **Poly Pizza** (filter by CC0/CC-BY).
- **ambientCG / Poly Haven** (CC0): sand, rock, asphalt and wood PBR textures, plus HDRIs.
- Paid packs are optional, if the owner buys them later (Synty POLYGON Western/Desert, etc.).

Until the owner supplies models, build **procedural placeholders**: capsule plus sphere soldiers with a spiky cone head, box cliffs with noise-displaced vertices, CSG fences and bridge. Put them behind a `UnitVisuals` resource so they can be swapped for real models with no code changes.

---

## 5. Performance rules (must follow)

The target is 60 fps on a mid-range phone (Snapdragon 6-series or Helio G-series, 4 GB RAM) with **1,500 friendlies + 700 enemies** on screen.

1. **Do not make each unit a Node.** Units are pure data in `PackedFloat32Array`/`PackedInt32Array` structure-of-arrays pools (pos x/z, vel x/z, value, radius, gate mask, flags), using swap-remove.
2. Render each unit type with **one `MultiMeshInstance3D`** (blue soldier, champion, red grunt, brute). Every frame, write the transforms into `multimesh.buffer` (a `PackedFloat32Array`) in a single assignment. Set `visible_instance_count` to the live count.
3. Animate the walk/bob in the **vertex shader** using `INSTANCE_ID` and `TIME`, plus INSTANCE_CUSTOM for phase and scale. No AnimationPlayer per unit.
4. Collisions use a **uniform spatial hash grid** (cell ≈ 2× the biggest radius) rebuilt each frame for enemies, then each friendly checks its 3×3 neighboring cells. No physics engine for units.
5. Run the simulation in `_physics_process` at a fixed 60 Hz (or a custom fixed step with an accumulator). Clamp the frame delta to 1/30.
6. **Pool everything**: particles, floating texts and audio players. No `instantiate()` or `queue_free()` in the hot loop.
7. Bake static geometry, keep draw calls under ~150, compress textures with ETC2/ASTC, keep textures ≤1024 px for props, and use LODs on cliffs.
8. Measure performance with the Godot profiler and `Performance.get_monitor()`. Add a debug overlay (toggled by a 3-finger tap in debug builds) showing FPS, unit counts and draw calls.

---

## 6. Project structure

```
gatecrush/
├─ project.godot
├─ export_presets.cfg            # Android preset; NO passwords in it
├─ CLAUDE.md  ASSETS_LICENSES.md  README.md  .gitignore
├─ addons/                       # (later) AdMob / Play Billing / Play Games plugins
├─ assets/
│  ├─ models/  textures/  materials/  shaders/  fonts/  audio/{sfx,music}/  ui/
├─ scenes/
│  ├─ boot.tscn  home.tscn  game.tscn
│  ├─ world/  road_segment.tscn  bridge.tscn  canyon_props.tscn  fort.tscn  boss_skeleton.tscn
│  ├─ gameplay/ cannon.tscn  gate.tscn
│  └─ ui/  hud.tscn  pause.tscn  result.tscn  upgrade_card.tscn
├─ scripts/
│  ├─ autoload/  save_manager.gd  audio_manager.gd  game_events.gd  haptics.gd
│  ├─ core/      crowd_sim.gd  spatial_grid.gd  unit_renderer.gd  fx_pool.gd  float_text_pool.gd
│  ├─ gameplay/  cannon.gd  gate.gd  enemy_base.gd  boss.gd  level_builder.gd  game_controller.gd
│  ├─ data/      level_def.gd (Resource)  gate_def.gd  unit_visuals.gd
│  └─ ui/        hud.gd  home.gd  pause.gd  result.gd  upgrade_card.gd
├─ levels/       level_001.tres … (hand-tuned first 20) + procedural generator beyond
└─ tests/        (GUT or simple headless test scenes for crowd_sim & economy)
```

---

## 7. Android / Play Store requirements

- **Package name:** `com.<ownername>.gatecrush`. Ask the owner for their reverse-domain name before the first export.
- **Target SDK:** whatever Google Play currently requires for new apps (check the Play Console policy page at build time; in 2025–26 that was API 35+). Min SDK 24.
- **Output:** Android App Bundle (`.aab`) for Play, and a universal `.apk` for sideload testing.
- **Signing:** use Play App Signing. The owner creates the upload keystore locally with `keytool`. **Never commit the keystore or its passwords.** Pass passwords through environment variables or Godot's `export_credentials.cfg` (gitignored).
- **Orientation:** portrait only. Immersive mode on. Handle display cutouts and safe areas in the UI.
- **Permissions:** keep to the minimum. Add `VIBRATE` for haptics. Add `INTERNET` and `ACCESS_NETWORK_STATE` only once ads or analytics are added.
- **Versioning:** increase `version/code` by 1 on every Play upload, and use semantic `version/name`.
- **Store listing items** (Claude can draft the text; the owner supplies the final images): 512×512 icon, 1024×500 feature graphic, at least 4 phone screenshots, short and full descriptions, privacy policy URL, Data Safety form answers, content rating questionnaire, and target audience. If the game could appeal to children, the Families policy applies, which affects ads.
- **Later monetization (milestone 6):** the AdMob Godot plugin with rewarded "×2 coins" and interstitials every 3 levels (never during gameplay), and a "remove ads" in-app purchase via the Google Play Billing plugin. Needs UMP consent for GDPR.

---

## 8. Milestones (build in this order and keep the game runnable after each)

1. **M1 — Core sim, graybox.** Road, camera, cannon, firing, MultiMesh soldiers, gates with cloning, enemies, spatial-grid combat, fort HP, win/lose. Placeholder primitives only. Desktop controls work.
2. **M2 — Game loop and UI.** Home, HUD, pause, result, save/load, coins and upgrades, level progression and the level generator.
3. **M3 — Art pass.** Desert canyon environment, bridge, fences, lighting, sky, fog, unit shaders with rim light, particles, floating crowd-count number, UI theme and fonts. Swap in CC0 models where available.
4. **M4 — Content.** Skeleton boss every 5th level, the extra gate types, 20 hand-tuned levels, difficulty curve.
5. **M5 — Feel and audio.** SFX (fire, gate, clash, base hit, win, lose), music loop, haptics, screen shake, slow-mo on win, juice tuning.
6. **M6 — Android release.** Export presets, icon and adaptive icon, splash, performance pass on a real device, optional ads/IAP, store listing drafts, release `.aab`.

---

## 9. How Claude should work in this repo

- Before starting a milestone, write a short plan, then implement it in small commits.
- Keep everything as text files: write `.tscn`/`.tres` by hand only when they are simple, and prefer building complex node trees in code inside `_ready()` for robustness.
- After every change, run:
  `godot --headless --path . --quit-after 300` (or `--check-only` per script) to catch parse errors, and report what was verified.
- Use typed GDScript and signals through the `GameEvents` autoload. No hidden globals. Keep magic numbers in `res://scripts/data/tuning.gd` constants.
- Never put secrets in the repo. Ask the owner for the package name, keystore, AdMob IDs and privacy policy URL; don't invent them.
- When something needs the owner's hands (installing tools, testing on a phone, uploading to the Play Console), say so clearly with exact steps.
- Keep `ASSETS_LICENSES.md` up to date whenever an asset is added.

---

## 10. Owner's machine setup (one-time, done by the owner)

1. Install **Godot 4.x (latest stable, standard)** from godotengine.org, and make the `godot` command available on PATH.
2. Install **Android Studio**. Then, in its SDK Manager, install: Android SDK Platform (current Play target API), Build-Tools, Platform-Tools, Command-line Tools, and the NDK version that Godot's docs list for your Godot version.
3. Install **JDK 17**. Godot 4 Android export expects JDK 17.
4. In Godot, go to **Editor → Manage Export Templates** and download the templates for your Godot version.
5. In Godot, open **Editor Settings → Export → Android** and set the Java SDK path and the Android SDK path.
6. In the project, go to **Project → Install Android Build Template** (needed for plugins like AdMob).
7. Create a debug keystore (Godot can generate one) and, later, the release upload keystore:
   `keytool -genkeypair -v -keystore upload.keystore -alias upload -keyalg RSA -keysize 2048 -validity 10000`
8. Plug in an Android phone with **USB debugging** on, and use Godot's one-click deploy for testing.
9. In VS Code, install the **godot-tools** extension and the **Claude Code** extension.

---

## 11. Decisions log

- **Godot version:** project targets Godot **4.7** (latest stable when M1 was written, 2026-10). `config/features` says 4.7.
- **Packed arrays are copy-on-write.** All hot loops write only to packed arrays that are members of the *same* object (`CrowdSim` owns every unit array, `UnitRenderer` owns every render buffer). Never write `other_obj.some_packed_array[i] = v` in a loop: it copies the whole array on each write.
- **Input actions** (`move_left`, `move_right`, `fire`, `pause`) are registered in code by `InputSetup.ensure_actions()` instead of being serialized in `project.godot`.
- **Camera** fits the lane from the pitch + vertical FOV at a 9:16 reference, then uses `KEEP_WIDTH` on taller screens and `KEEP_HEIGHT` on wider ones, so the lane always fits.
- **Champions** are the 26th shot (replacing that soldier), not an extra unit.
- **Until M4**, every level (including every 5th) ends in a fort; the boss replaces it in M4.
- **First run** needs an import pass so `class_name` globals are registered: open the project in the editor once, or run `godot --headless --path . --import`.
