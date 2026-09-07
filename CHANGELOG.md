# Changelog

All notable changes to the Sipeed Tang Primer 20K Space Wars-style game.

## [1.01.DONE] - 2026-09-06

**Final board release** for this GW2A-18 tree. FPGA is full (Logic ~93%, BSRAM 100%) — no room for menus, SSRAM, or SPI.

### Added / changed (board-tested)
- DIP5 attract test mode (pin T5): **up** = normal attract, **down** = test (fly Diamond, AI frozen; Fire shoots)
- AI `want_facing` ~5 deg bins in all modes (no 90 deg cardinal snap)
- Countdown timer MM/SS each 0..59 (max **59:59**; match start **01:30**)
- Synth snapshot and full Gowin dump in `FPGA_Data.text`
- README: ship art, tweak knobs via `sw_config.vh`, project complete banner

### Notes
- Version string: `1.01.DONE`
- Timing still does not close at 33 MHz (Fmax ~8 MHz); board-tested anyway

## [1.01.3] - 2026-09-05

Board-OK physics updates on `savepoint/working-bsram-pre-ddr3`.

### Added / changed (board-tested)
- BH red border: max speed 1/4; margin contact kills (invuln still bounces)
- Attract test mode: hold S0+S1+S2 ~3s (pixel-clk timer); freeze AI; Diamond user control; Fire shoots (does not start match)

### Notes
- Branch: `savepoint/working-bsram-pre-ddr3`
- Open: config menu UI, optional AI maxv ramp

## [1.01.2] - 2026-09-05

Board-OK starfield on `savepoint/working-bsram-pre-ddr3`.

### Added / changed (board-tested)
- Constellation night-sky catalog (`star_field_rom.vh`): 360deg x wrap map, 90deg window
- Random drift L/R/U/D (diagonals OK) at 1 px/frame; wrap on both axes
- Stars are scanout overlay under ships/shots
- Gowin: keep `star_field_rom.vh` on disk for `include` only (not FileList)

### Notes
- Branch: `savepoint/working-bsram-pre-ddr3`
- Open: config menu UI, AI maxv ramp, test mode, BH border kill + 1/4 maxv

## [1.01.1] - 2026-09-05

Working board update on the way to a fuller 1.01.x (more still to add).

### Added / changed (board-tested)
- Wrap at playfield edges (default); **black** rim; **red** rim + bounce in black-hole mode
- BH->sun outward 1/r^2 for `CFG_ANTI_GRAV_SEC`, then clear (soft Fire-start resets sun state)
- Secret green sun (config knobs only; not described in README)
- Shot streak erase: clamp endpoints to FB (fixes wrap leftover ink)

### Notes
- Branch: `savepoint/working-bsram-pre-ddr3`
- Open / not done yet: config menu UI, test mode, BH border kill + 1/4 maxv, etc.

## [1.0.0] - 2026-09-05

First full release of the board-tested working game (BSRAM playfield).

### Highlights
- Tang Primer 20K Dock + 5" 800x480 RGB LCD playable match loop
- Diamond (player) vs yellow AI wedge; attract demo; hyperspace (S0)
- Scores, lives, fuel, MM:SS timer, sun / black hole, vanish deaths
- Board-OK polish: shorter negative-score minus bar; thrust x1.5; max speed 16

### Baseline
- Branch / tag: `v1.0.0` from known-good BSRAM tree (`savepoint/working-bsram-pre-ddr3`)
- See `docs/SAVEPOINT-working-bsram-pre-ddr3.md` and `docs/Gowin-copy-bsram.txt`

### Not in 1.0.0
- DDR3 framebuffer, death segment-drift anim, config menu UI, green-sun secret

## [0.3.0] - 2026-09-05

Attract demo, hyperspace, vanish deaths, config header, HUD digit latch.

### Added
- Attract / demo: both ships AI; Diamond hunts; unlimited life/fuel; timer wraps **00:00 -> 99:99**
- **PUSH FIRE TO START** (bright green) after boot and GAME OVER; fire soft-starts when draw idle
- **S0 hyperspace** (`btn_hyper_n` on T10): vanish ~1 s -> random warp -> ~1.5 s red/green flash @ ~10 Hz + invuln
- Reset is **PLL lock only** (no button reset)
- Spawn invuln **1.5 s**; sun/shot deaths **vanish** then respawn
- AI shot life capped at **<= 75%** player; AI playtime ramps through **5:00**
- Shot bank **8** (player 0-4, AI 5-7)
- `sw_config.vh` knobs: `` `include `` from `sw_physics.v` **and** listed on Gowin FileList
- Scanout: HUD timer/score/fuel/flash fields latched into FFs once per clock (less pixel combo)

### Changed
- Match timer encoding remains **MMx100+SS** (starts **01:30**); score **999 -> 0** rollover
- Kill/sun/BH: vanish then respawn
- README aligned with board behavior

### Notes
- AG0100/AG0101 WARNs alone are not treated as fail if bitstream plays

## [0.2.0] - 2026-09-03

Playable match loop on the 5" LCD - starting to look like a real game.

### Added
- Center **MM:SS** countdown (starts 1:30); yellow under 0:30, red under 0:10; +5 s on a shot kill
- Player **lives** (wedge icons, start 3 / max 5); bonus life every 5 AI kills; game over at 0 lives or 0:00
- Flashing red **GAME OVER** (2 Hz, 50% duty), vertically centered
- Vertical **fuel** gauge (15 s thrust); green / <=10% yellow / <=5% red; empty = no thrust until respawn
- **Black hole**: 10 shots into the sun -> sun vanishes, soft attract gravity, red border
- Shoot the black hole **5 times** (player) -> sun returns with soft **repulsion**; border white again
- Hitting sun / BH / restored-sun core costs the player a life

### Changed
- Scores render bright light blue
- Timer dimmed ~20% vs full white
- Border can switch white <-> red with black-hole mode

### Notes
- AI still has unlimited ships; ram still -1 each; walls bounce; Gowin Education build

## [0.1.0] - earlier

- Vector Diamond vs AI wedge, orange sun, shots, Pong-style scores, erase/redraw FB
