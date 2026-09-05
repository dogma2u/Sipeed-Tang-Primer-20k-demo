# Sipeed Tang Primer 20K demo

**This is starting to look like a real game.** Still a work in progress on FPGA — expect more changes — but the match loop (timer, lives, fuel, sun / black hole, attract, hyperspace) plays through on the Dock + 5" LCD.

A **space ship fighting game** on the **Sipeed Tang Primer 20K Dock** with the **5" 800×480 RGB LCD**. You fly the **Diamond**; a yellow AI wedge hunts and shoots. Vector outlines, orange sun (and black hole), bounce walls, scores, fuel, and a countdown. Inspired by the 1977 *Space Wars* arcade (sun, thrust, shots) but this is original HDL — not a ROM dump.

Version **0.3.0** — see [CHANGELOG.md](CHANGELOG.md).

![Tang Primer 20K Dock and LCD — Space Wars demo](docs/20260903_dock.jpg)

![Tang Primer 20K Dock and LCD — close-up](docs/20260903_111330.jpg)

## Hardware

| Item | Used here |
|---|---|
| Board | Sipeed Tang Primer 20K Dock |
| FPGA | Gowin GW2A-LV18PG256C8/I7 (GW2A-18C), 46 BSRAM |
| Display | 5" 800×480 RGB LCD (RGB565, 5 px white border) |
| Clock | 27 MHz on H11 → rPLL **33 MHz** pixel clock |
| Tools | Gowin FPGA Designer (synthesize / program) |

**DIP switch 1 down.** Keys are active-low. Dock buttons sit on a **1.5 V** bank (`LVCMOS15`); LCD, clock, and reset are **3.3 V** (`LVCMOS33`).

| Button | Pin | Action |
|---|---|---|
| S1 | T3 | Rotate left |
| S2 | T2 | Rotate right |
| S3 | D7 | Thrust |
| S4 | C7 | Fire |
| S0 | T10 | Hyperspace |

FPGA reset is **PLL lock only** (no button reset). **S0** is hyperspace: ship vanishes ~1 s, warps to a random spot, then flashes red/green ~1.5 s at ~10 Hz with spawn invulnerability.

You fly a top-down **Diamond**. The other ship is an Asteroids-style wedge (AI). Thrust flame comes from the middle of the hull.

## Attract / start

On boot (and after **GAME OVER**), the board runs an **attract demo**: both ships are AI, the Diamond hunts, life/fuel are unlimited, and the timer wraps **00:00 → 99:99**. Bright green **PUSH FIRE TO START** sits under the playfield text. Press **Fire** when draw is idle to soft-start a match (timer **01:30**, lives/fuel restored).

## Scoreboard

Pong-style **block digits** at the top of the LCD: **player left**, **AI right** (bright light blue), and a **MM:SS** counter in the center (value = **MM×100+SS**; MM and SS each **0..99**; match starts at **01:30**). Timer turns **yellow** under 0:30 and **red** under 0:10. **Three score digits** each with **leading-zero blanking** (range −999 to 999; **999 → 0** on next +1). If a score goes below zero, a minus bar appears. Under the **player** score are **wedge life icons** (start with 3, max 5); a kill that costs you a life removes one. Every **5 AI kills** grants an extra life if you have fewer than 5. To the right of the player score is a **vertical fuel bar** (same height as the score digits, **15 s** of thrust): **green**, **yellow** at ≤10% left, **red** at ≤5%; empty means no thrust until you respawn with a full tank. The AI has **unlimited** ships (no life icons, never ends the game by AI deaths).

| Event | Player (left) | AI (right) | Timer |
|---|---|---|---|
| Your shot destroys the AI | +1 | — | +5 s |
| AI shot destroys you | — | +1 | +5 s |
| Ships crash into each other | −1 | −1 | — |
| Hit the sun / bounce a wall | no score change | no score change | — |

A crash also bounces the ships apart so it only counts once. Deaths **vanish** then respawn (AI always; player only if lives remain). No boom X. Respawn can land anywhere (including on the sun); **1.5 s** invuln after spawn. Sun/BH kills park the ship off-screen briefly, then respawn with **zero velocity**.

**Game over.** When the timer reaches **0:00**, or the player has **no lives left**, play freezes and block **GAME OVER** flashes in the center (2 times per second, 50% duty), with **PUSH FIRE TO START** below.

## How it works

**Scanout.** Overlay stack, back to front: HUD → 2-bit FB ink (Diamond green, AI yellow, shots white) → star ROM → sun / black hole. **GAME OVER** / **PUSH FIRE** on top. HUD digit, fuel, and flash fields are **latched into FFs** each clock so the pixel path is mostly compares. Hyperspace flash tints the Diamond red/green in scanout.

**Modules.** Game logic is split: `sw_physics.v` (AI, gravity, shots, scores, HS), `sw_draw.v` (erase/stroke), `sw_scanout.v` (LCD composite). `space_wars.v` is thin glue plus shared `sin_cos` / `fb_ram`. Shots use an indexed bank of **8** (player 0–4, AI 5–7). Tunables live in `sw_config.vh` (`` `define `` macros): included from `sw_physics.v` and listed on the Gowin FileList.

**Framebuffer.** 800×470 **2-bit** BRAM (color at draw: empty / player / AI / shots). Full 800×480×2 overflows the 20K’s 46 BSRAM, so the bottom 10 LCD lines stay black. Stars are a tiny coordinate ROM at scanout (in front of ships). A second full playfield page also will not fit (~41 BSRAM each); erase/redraw on one FB, with physics frames dropped while draw is busy. FB writes are FF-pipelined (1 cycle) in `space_wars.v`.

**Sun.** Not stored in the FB. During scanout it is composited as an orange circle at (400, 240), radius 18, **in front of the ships**. Hitting the sun (or black-hole / restored-sun core) **costs the player a life** (vanish path). After **10 shots** hit the sun, it becomes a **black hole** with **1/r²** gravity (thrust can still fight it) and a **red border**. **5 player shots** into the hole restore the sun with **outward 1/r²** push.

**Ships.** Vertex outlines, `sin_cos.v`, Q8.8 positions. Diamond **green**, AI **bright yellow**, shots white. Mag: **5 shots / ~500 ms**, then **500 ms** reload; one shot per tap. AI bullets live at most **~75%** of player shot life.

**AI.** Hidden elapsed playtime ramps shot range, standoff, aim, and thrust through **5:00**; hunts by closing range and turning smoothly; avoids walls and (in match) steering/firing through the sun.

**Stars.** 28-point ROM at scanout, in front of ships.

Per-frame flow (simplified): physics → bounce / sun / shots → erase old vectors → stroke ships → shot streaks.

## Source (what Gowin builds)

Project: [`fpga/tang20k_lcd/tang20k_lcd.gprj`](fpga/tang20k_lcd/tang20k_lcd.gprj)

| File | Role |
|---|---|
| `src/top.v` | Glue: PLL, LCD, game, buttons |
| `src/gowin_rpll.v` | 27 → 33 MHz rPLL |
| `src/lcd_timing.v` | 800×480 timing, border, `frame_start` |
| `src/space_wars.v` | Game glue: FB, sin_cos, handshakes |
| `src/sw_physics.v` | Physics, AI, shot bank, scores, sun/BH, HS |
| `src/sw_draw.v` | Erase / stroke ships / shots |
| `src/sw_scanout.v` | HUD, stars, sun, FB color → RGB |
| `src/sw_config.vh` | Gameplay `` `define `` knobs (include + FileList) |
| `src/fb_ram.v` | 2-bit 800×470 BRAM |
| `src/sin_cos.v` | Quarter-wave sine/cosine |
| `src/tang20k_lcd.cst` | Pin constraints |
| `src/tang20k_lcd.sdc` | 27 MHz clock constraint |

## Build

1. Open `fpga/tang20k_lcd/tang20k_lcd.gprj` in Gowin FPGA Designer.
2. Synthesize / place & route for **GW2A-LV18PG256C8/I7**.
3. Program the Dock. DIP 1 down, LCD seated.

If you keep a separate Gowin tree, copy **all** of `fpga/tang20k_lcd/src/*.v` **and** `sw_config.vh` into that project. Keep `sw_config.vh` on the FileList (`` `define ``-only header). Add `sw_physics.v` / `sw_draw.v` / `sw_scanout.v` if missing, then rebuild.

## License

MIT — see [LICENSE](LICENSE). Early demo code, no warranty, not finished software.
