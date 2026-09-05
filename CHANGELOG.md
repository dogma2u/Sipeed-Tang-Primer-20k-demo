# Changelog

All notable changes to the Sipeed Tang Primer 20K Space Wars–style demo.

## [0.3.0] — 2026-09-05

Attract demo, hyperspace, vanish deaths, config header, HUD digit latch.

### Added
- Attract / demo: both ships AI; Diamond hunts; unlimited life/fuel; timer wraps **00:00 → 99:99**
- **PUSH FIRE TO START** (bright green) after boot and GAME OVER; fire soft-starts when draw idle
- **S0 hyperspace** (`btn_hyper_n` on T10): vanish ~1 s → random warp → ~1.5 s red/green flash @ ~10 Hz + invuln
- Reset is **PLL lock only** (no button reset)
- Spawn invuln **1.5 s**; sun/shot deaths **vanish** then respawn (no boom X)
- AI shot life capped at **<= 75%** player; AI playtime ramps through **5:00**
- Shot bank **8** (player 0–4, AI 5–7)
- `sw_config.vh` knobs: `` `include `` from `sw_physics.v` **and** listed on Gowin FileList
- Scanout: HUD timer/score/fuel/flash fields latched into FFs once per clock (less pixel combo)

### Changed
- Match timer encoding remains **MM×100+SS** (starts **01:30**); score **999 → 0** rollover
- Kill/sun/BH: no expanding X; draw boom ports tied off
- README aligned with board behavior

### Notes
- Deferred: death segment-drift (todo 10) — see `docs/deferred-9-10-11.md`
- AG0100/AG0101 WARNs alone are not treated as fail if bitstream plays

## [0.2.0] — 2026-09-03

Playable match loop on the 5" LCD — starting to look like a real game.

### Added
- Center **MM:SS** countdown (starts 1:30); yellow under 0:30, red under 0:10; +5 s on a shot kill
- Player **lives** (wedge icons, start 3 / max 5); bonus life every 5 AI kills; game over at 0 lives or 0:00
- Flashing red **GAME OVER** (2 Hz, 50% duty), vertically centered
- Vertical **fuel** gauge (15 s thrust); green / ≤10% yellow / ≤5% red; empty = no thrust until respawn
- **Black hole**: 10 shots into the sun → sun vanishes, soft attract gravity, red border
- Shoot the black hole **5 times** (player) → sun returns with soft **repulsion**; border white again
- Hitting sun / BH / restored-sun core costs the player a life

### Changed
- Scores render bright light blue
- Timer dimmed ~20% vs full white
- Border can switch white ↔ red with black-hole mode

### Notes
- AI still has unlimited ships; ram still −1 each; walls bounce; Gowin Education build

## [0.1.0] — earlier

- Vector Diamond vs AI wedge, orange sun, shots, Pong-style scores, erase/redraw FB
