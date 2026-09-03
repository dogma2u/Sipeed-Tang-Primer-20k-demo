# Sipeed Tang Primer 20K demo

**This is starting to look like a real game.** Still a work in progress on FPGA — expect more changes — but the match loop (timer, lives, fuel, sun / black hole) plays through on the Dock + 5" LCD.

A **space ship fighting game** on the **Sipeed Tang Primer 20K Dock** with the **5" 800×480 RGB LCD**. You fly a TOS-style Enterprise; an AI wedge chases and shoots poorly. Vector outlines, orange sun (and black hole), bounce walls, scores, fuel, and a countdown. Inspired by the 1977 *Space Wars* arcade (sun, thrust, shots) but this is original HDL — not a ROM dump.

Version **0.2.0** — see [CHANGELOG.md](CHANGELOG.md).

![Tang Primer 20K Dock and 5" LCD running the space ship fighting demo](docs/20260903_014250.jpg)

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
| S0 | T10 | Reset |

You fly a top-down TOS-style Enterprise. The other ship is an Asteroids-style wedge (AI). Thrust flame comes from the middle of the hull.

## Scoreboard

Pong-style **block digits** at the top of the LCD: **player left**, **AI right** (bright light blue), and a **M:SS countdown** in the center (starts at **1:30**). Timer turns **yellow** under 0:30 and **red** under 0:10. Two score digits each. If a score goes below zero, a minus bar appears next to it. Range is −99 to 99. Under the **player** score are **wedge life icons** (start with 3, max 5); a shot that kills you removes one. Every **5 AI kills** grants an extra life if you have fewer than 5. To the right of the player score is a **vertical fuel bar** (same height as the score digits, **15 s** of thrust): **green**, **yellow** at ≤10% left, **red** at ≤5%; empty means no thrust until you respawn with a full tank. The AI has **unlimited** ships (no life icons, never ends the game by AI deaths). **S0** reset clears scores, player lives, fuel, and the timer.

| Event | Player (left) | AI (right) | Timer |
|---|---|---|---|
| Your shot destroys the AI | +1 | — | +5 s |
| AI shot destroys you | — | +1 | +5 s |
| Ships crash into each other | −1 | −1 | — |
| Hit the sun / bounce a wall | no score change | no score change | — |

A crash also bounces the ships apart so it only counts once. Shot kills still boom (expanding X) then respawn (AI always; player only if lives remain).

**Game over.** When the timer reaches **0:00**, or the player has **no lives left**, play freezes and block **GAME OVER** flashes in the center of the screen (2 times per second, 50% duty).

## How it works

**Scanout.** `lcd_timing.v` generates 800×480 timing and overlays the border. Game pixels come from `space_wars.v`.

**Framebuffer.** One **800×480 1-bit** BRAM (`fb_ram.v`) holds vector ink (ships, stars, shots, explosions). Double-buffering does not fit in 46 BSRAM. The buffer is cleared **once at boot**. After that the game **erases last frame’s lines and draws the new ones**. A full clear every frame races the LCD beam and leaves you with a blank screen.

**Sun.** Not stored in the 1-bit FB. During scanout it is composited as an orange, limb-darkened circle at (400, 240), radius 18. Ships bounce on the playfield margin. Hitting the sun (or black-hole / restored-sun core) **costs the player a life** and booms; the AI just respawns. After **10 shots** hit the sun (player or AI), it collapses into a **black hole**: the orange sun vanishes, soft center gravity turns on (thrust can overcome it), and the screen **border turns red**. If the **player** then shoots the black-hole core **5 times**, the **sun returns** with **negative gravity** (soft push outward; thrust can overcome it) and the border goes back to white.

**Ships.** Outlines are small integer vertices, rotated with `sin_cos.v` (angle 0..255). Positions are 24-bit Q8.8 so they do not wrap at 16-bit. Walls bounce.

**AI.** The wedge turns toward the Enterprise, slowly and with skipped frames, coasts when close, and fires on a long cooldown with a wide cone and a random side miss. Each side has its own shot. A hit is an expanding X, then respawn.

**Stars.** 28 constellation points are replotted every frame so erase/redraw does not wipe the sky.

Per-frame flow (simplified): physics → bounce / sun / shots → erase old vectors → plot stars → transform and stroke ships → draw shot streaks → boom if needed.

## Source (what Gowin builds)

Project: [`fpga/tang20k_lcd/tang20k_lcd.gprj`](fpga/tang20k_lcd/tang20k_lcd.gprj)

| File | Role |
|---|---|
| `src/top.v` | Glue: PLL, LCD, game, buttons |
| `src/gowin_rpll.v` | 27 → 33 MHz rPLL |
| `src/lcd_timing.v` | 800×480 timing, border, `frame_start` |
| `src/space_wars.v` | Game: physics, AI, vectors, shots, scores |
| `src/fb_ram.v` | 1-bit 800×480 BRAM |
| `src/sin_cos.v` | Quarter-wave sine/cosine |
| `src/tang20k_lcd.cst` | Pin constraints |
| `src/tang20k_lcd.sdc` | 27 MHz clock constraint |

## Build

1. Open `fpga/tang20k_lcd/tang20k_lcd.gprj` in Gowin FPGA Designer.
2. Synthesize / place & route for **GW2A-LV18PG256C8/I7**.
3. Program the Dock. DIP 1 down, LCD seated.

If you keep a separate Gowin tree, copy `fpga/tang20k_lcd/src/` into that project and rebuild.

## License

MIT — see [LICENSE](LICENSE). Early demo code, no warranty, not finished software.
