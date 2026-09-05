# Savepoint: working BSRAM playfield (pre-DDR3 attempt)

**Date:** 2026-09-05  
**Status:** WORKING and BOARD-TESTED (James confirmed; includes minus bar + thrust/maxv tweaks @ `5743da8`).  
**Release:** **v1.0.0** on `main` (first full release).  
**Purpose:** Known-good BSRAM playfield baseline.

## Git

- **Branch (push target):** `savepoint/working-bsram-pre-ddr3`
- **Remote:** `origin` → `https://github.com/dogma2u/Sipeed-Tang-Primer-20k-demo.git` (current workspace `origin`; this is where the Tang LCD project history lives)
- **Version at save:** `0.3.0` (see `VERSION`, `CHANGELOG.md`)
- **How to revert if DDR3 work fails:**
  1. `git fetch origin`
  2. `git checkout savepoint/working-bsram-pre-ddr3`
  3. Copy `fpga/tang20k_lcd/src/*` (and `.cst` / `.gprj` as needed) back into the Gowin tree
  4. Or reset your working branch to this commit after confirming

Do **not** treat GitHub `main` as this baseline unless it matches this branch.

## Design state (known-good)

### Hardware / video
- Tang Primer 20K Dock + 5" 800x480 RGB LCD
- Pixel clock ~33 MHz (rPLL from 27 MHz)
- Playfield FB: **on-chip BSRAM**, 800x470 x **2-bit** (`fb_ram.v`)
- Bottom 10 LCD lines black (full 800x480x2 does not fit 46 BSRAM)
- LCD **border** is scanout-only (not in FB); does not need its own buffer
- **Double-buffer in BSRAM does not fit** (~41 BSRAM per 2-bit page; chip has 46)
- DDR3 (128 MB on SOM) exists but is **not used** in this savepoint

### Modules
- `sw_physics.v` -- AI, gravity, shots, scores, hyperspace, attract
- `sw_draw.v` -- erase / stroke (no boom X)
- `sw_scanout.v` -- HUD / stars / sun / FB ink; HUD fields latched in FFs
- `space_wars.v` -- glue; FB **write** path FF-pipelined (1 cycle); read addr combo
- `sw_config.vh` -- `` `define `` knobs; **include + FileList**
- `top.v` -- `rst_n = pll_lock` only; S0 = hyperspace (`btn_hyper_n` T10)

### Gameplay (board-confirmed highlights)
- Diamond (player) vs yellow AI wedge
- Attract: both AI; Diamond hunts; timer wrap 00:00 -> 99:99; PUSH FIRE TO START
- Match timer MM*100+SS starts 01:30
- Vanish deaths (no boom X); spawn invuln 1.5 s
- S0 hyperspace: vanish / warp / red-green flash + invuln
- Shot bank 8 (player 0-4, AI 5-7)
- Demo: turn step 4 every frame; DEMO_THRUST = top thrust * 1.5; SHIP_MAXV clamp 21

### Reg/FF preferences already applied
- Scanout HUD digit/fuel/flash latched
- Physics AI ramp / keep-out latches
- `space_wars` FB write en/addr/data latched; `draw_busy_r` for frame_kick
- Do **not** pipeline FB read addr without re-aligning scanout
- Do **not** chase AG0100/AG0101 WARNs if bitstream plays

### Gowin copy set (this savepoint)
All under `fpga/tang20k_lcd/`:
- `src/*.v`, `src/sw_config.vh`, `src/tang20k_lcd.cst`, `src/tang20k_lcd.sdc`
- `tang20k_lcd.gprj` (FileList includes `sw_config.vh`)

ASCII-only in `.v` / `.vh` comments (Education parser).

## Todo list at savepoint (open only)

1. Compress large docs/ JPGs
2. GitHub About blurb on Sipeed repo (manual Edit description)
3. Config menu: wire sw_config.vh knobs to runtime regs / UI
4. Optional AI-only CFG_AI_MAXV_* max-speed ramp (reserved, not applied)
6. Secret green sun: 50 user shots to sun/BH -> green; strong +/-/random grav on AI only (incl. demo); Diamond exploits; knobs in sw_config only, NOT in README
7. BH->sun outward 1/r^2 push lasts CFG_ANTI_GRAV_SEC (10s) then clears; soft match reset path (not full FPGA/PLL reset)
8. ~~Minus sign for negative score too long on right-side (AI) score~~ (board OK 2026-09-05; MINUS_W=16)
9. ~~Make thrust another 1.5x (on top of current demo DEMO_THRUST); reduce max speed by 25%~~ (board OK 2026-09-05; PL/AI thr x1.5, SHIP_MAXV 16)

## Explicitly cancelled / not in this baseline
- Full BSRAM double-buffer playfield (does not fit)
- Border 5px all sides -> playable FB 790x470 (cancelled; BSRAM not enough for 2nd page)
- DDR3 playfield buffering (attempted then abandoned; local sources removed)
- Death segment-drift / breakup anim (tried scanout-only; no visible change on board; reverted)
- Nacelles, AI L/C/R guns, button debounce (skipped)
- Boom X death anim

## Notes for DDR3 (parked)
- SOM has 128 MB DDR3 -- capacity OK for multi-page FB
- Needs DDR3 controller/PHY, clocks, scanout FIFO, draw burst path, SystemVerilog
- Keep this BSRAM design intact; do not mix Desktop zip trees with this repo
