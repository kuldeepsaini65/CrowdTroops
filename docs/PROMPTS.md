# Prompts to paste into Claude in VS Code

Put `CLAUDE.md` in the root of an empty project folder (for example `gatecrush/`), open that folder in VS Code, start Claude, and paste the prompts below one at a time. Paste the next prompt only after the previous milestone runs correctly on your machine.

---

## Prompt 1 — Kickoff + Milestone 1

```
Read CLAUDE.md completely. It is the full spec for this project: a 3D crowd-cannon game called Gatecrush, built in Godot 4 (GDScript), for release on Google Play.

Start with Milestone 1 (core simulation, graybox):
1. Create project.godot (Mobile renderer, portrait 1080x2340 base, stretch mode canvas_items/expand), the .gitignore, the folder structure from §6, and the autoloads (GameEvents, SaveManager, AudioManager stub, Haptics stub).
2. Build game.tscn: road lane, camera rig with follow and shake, directional light with shadows, a simple sky.
3. Implement crowd_sim.gd with structure-of-arrays pools, swap-remove, the spatial hash grid, gate bitmasks, clone-cap overflow and champion rules, exactly as in §3 and §5.
4. Implement unit_renderer.gd using one MultiMeshInstance3D per unit type, with a vertex-shader bob/walk animation.
5. Cannon with drag and keyboard controls and auto-fire, moving gates with labels, an enemy fort with an HP bar and spawning, wall line, win/lose detection.
6. Use placeholder primitives only for now.

Before writing code, give me a short plan. After coding, run Godot headless to check for parse errors, fix any errors you find, and tell me exactly how to run the game and what to test.
```

## Prompt 2 — Game loop and UI

```
Milestone 1 works. Now do Milestone 2 from CLAUDE.md: home screen, HUD, pause, result screen, save/load with atomic writes, coins and the three upgrades, level progression, and a level generator using the formulas in §3. Use a clean, chunky mobile UI theme (bold outlined font, glossy rounded buttons) and handle safe areas and notches. Verify headless, then tell me how to test it.
```

## Prompt 3 — Art pass (make it look like the reference)

```
Do Milestone 3 from CLAUDE.md: make it look like the reference image described in §4. Desert canyon with sandstone cliffs, a chasm with fog, a wooden bridge with concrete abutments, an asphalt road with dashed lines, wooden fences, cacti and rocks, warm sun and soft shadows, ACES tonemap with light bloom, and glossy soldiers with rim lighting and spiky heads (blue team and red team). Add a floating crowd-count number, particles for clashes, gates, champion trail and fort destruction, and glossy purple gate panels.
Build placeholders procedurally where needed. Also give me a list of specific CC0 asset packs (Kenney, Quaternius, Poly Haven, ambientCG) to download, and exactly which folders to put them in, so you can swap them in afterwards. Keep it at 60 fps on mid-range Android, following the §5 rules.
```

## Prompt 4 — Boss and content

```
Do Milestone 4: a giant skeleton boss on every 5th level (glowing fire hammer, HP number over its head, ground-slam area attack, slow advance), the new gate types, 20 hand-tuned level resources, and a smooth difficulty curve. Then play-balance the numbers and explain the tuning.
```

## Prompt 5 — Feel and audio

```
Do Milestone 5: SFX and music through a pooled AudioManager (tell me which CC0 sound packs to download, or generate simple placeholder sounds), haptics, screen shake, slow-motion on win, hit-stop on champion impact, and general juice. Add a debug performance overlay for debug builds only.
```

## Prompt 6 — Android release

```
Do Milestone 6: set up the Android export preset (AAB + APK, arm64-v8a, the current Play target SDK, min SDK 24, portrait, immersive, VIBRATE permission only), app icon and adaptive icon, boot splash, and versioning. Walk me step by step through creating my upload keystore, exporting a signed release .aab, testing the .apk on my phone, and filling in the Play Console (store listing, Data Safety, content rating, internal testing track, then production). Draft the store listing text and a simple privacy policy for me. My package name is: com.______.gatecrush
```

---

## If something breaks

```
The game shows this error / behaves like this: <paste error or describe>. Find the root cause, fix it, re-run the headless check, and tell me what changed.
```

```
It runs at about __ fps on my phone (<model>) with about __ units. Profile and optimize using the §5 rules without reducing visual quality more than necessary.
```
