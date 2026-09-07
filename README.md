<div align="center">

# Sipeed Tang Primer 20K — Space Wars

---

> [!IMPORTANT]
> ### Game over — end of the line
>
> This FPGA is **full**. Logic is packed to the brim, **every BSRAM** is spoken for, and there is no room left for a menu system, onboard **SDRAM** (DDR3), or SPI.
>
> The board game stops here. No bigger feature set on this chip — just the match you can play today.
> Want a different feel? Edit the knobs in [`sw_config.vh`](fpga/tang20k_lcd/src/sw_config.vh) (see **Tweaking gameplay** below).
>
> **GAME OVER.** Thanks for flying.

---

**Version 1.01.DONE** — board-tested on the Tang Primer 20K Dock + 5" LCD. Final release for this FPGA (chip is full).

Original HDL game inspired by the 1977 *Space Wars* arcade (sun, thrust, shots) — not a ROM dump. You fly the **Diamond**; a yellow AI **wedge** hunts and shoots. Vector outlines, orange sun / black hole, bounce walls, scores, fuel, and a countdown.

See [CHANGELOG.md](CHANGELOG.md) and [VERSION](VERSION).

<video src="https://github.com/user-attachments/assets/6ea7ac7b-8eb3-4649-b89f-231c46eaa664" controls autoplay muted loop playsinline width="100%"></video>

## Play now (web)

**[Launch the playable web version](https://dogma2u.github.io/tang-prime-web-space-wars/)**

Open that link to run the game in your browser (no install, no FPGA board). Attract demo starts on load — press **Fire** (`Space` / `K`) for a 1:30 match.

## Ships

<table align="center">
  <tr>
    <td align="center" valign="middle">
      <img src="docs/diamond-ship.svg" alt="Diamond ship (player) — green outline on LCD" width="400" height="400" />
    </td>
    <td align="center" valign="middle">
      <p align="center">On the LCD, outlines match these roles:</p>
      <table align="center">
        <thead>
          <tr>
            <th align="center">Ship</th>
            <th align="center">Who</th>
            <th align="center">Outline on LCD</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td align="center"><strong>Diamond</strong></td>
            <td align="center">Player</td>
            <td align="center">Bright <strong>green</strong></td>
          </tr>
          <tr>
            <td align="center"><strong>Wedge</strong></td>
            <td align="center">AI</td>
            <td align="center">Bright <strong>yellow</strong></td>
          </tr>
        </tbody>
      </table>
    </td>
    <td align="center" valign="middle">
      <img src="docs/wedge-ship.svg" alt="Wedge ship (AI) — yellow outline on LCD" width="400" height="400" />
    </td>
  </tr>
</table>

*Left: Diamond (you). Right: Wedge (AI). Thrust flame is drawn from mid-hull in-game.*

Hyperspace flashes the Diamond **red/green** for about 1.5 s. Shots render **white**.

## Hardware

| Item | Used here |
|:----:|:---------:|
| Board | Sipeed Tang Primer 20K Dock |
| FPGA | Gowin GW2A-LV18PG256C8/I7 (GW2A-18C), 46 BSRAM |
| Display | 5" 800×480 RGB LCD (RGB565; 5 px rim — black normally, red in black-hole mode) |
| Clock | 27 MHz on H11 → rPLL **33 MHz** pixel clock |
| Tools | Gowin FPGA Designer (synthesize / program) |

**DIP1 down** enables the core (required for flash / run). **DIP5 up** = normal attract; **DIP5 down** = attract **test mode** (you fly the Diamond, AI frozen; Fire shoots instead of starting a match).

Keys are active-low. Dock buttons and DIP2–5 use a **1.5 V** bank (`LVCMOS15`); LCD, clock, and reset use **3.3 V** (`LVCMOS33`).

| Control | Pin | Action |
|:-------:|:---:|:------:|
| S0 | T10 | Hyperspace |
| S1 | T3 | Rotate left |
| S2 | T2 | Rotate right |
| S3 | D7 | Thrust |
| S4 | C7 | Fire / start match |
| DIP5 | T5 | Attract test when **down** (up = normal) |

FPGA reset is **PLL lock only** (no button reset). Hyperspace: vanish ~1 s → random warp → ~1.5 s red/green flash at ~10 Hz with spawn invulnerability.

## Tweaking gameplay

There is no in-game menu, but you can retune the match in [`fpga/tang20k_lcd/src/sw_config.vh`](fpga/tang20k_lcd/src/sw_config.vh). Change a `` `define ``, re-synthesize in Gowin, and reprogram the board.

Common knobs:

| Define | What it does | Default (this tree) |
|:------:|:------------:|:-------------------:|
| `CFG_FUEL_MAX_MS` | Player thrust fuel budget (ms) | `15000` (15 s) |
| `CFG_TIMER_START` | Match countdown start (`MM×100+SS`) | `130` (01:30) |
| `CFG_TIMER_MAX` / `CFG_DEMO_TIMER` | Cap / attract wrap (`MM×100+SS`) | `5959` (59:59) |
| `CFG_SHIP_MAXV` | Max ship speed (all modes) | `10` |
| `CFG_PL_THRUST` | Player thrust strength | `60` |

Also nearby: lives (`CFG_LIFE_START` / `CFG_LIFE_MAX`), shot speed / magazine, sun and AI ramps. Keep timer fields as `MM×100+SS` with each part **0…59**. Extreme values can change feel a lot; synth/util usually stays similar if you only touch these numbers.

## Attract / start

On boot and after **GAME OVER**, an **attract demo** runs: both ships are AI-controlled, life and fuel are unlimited, and the timer wraps **00:00 → 59:59**. Bright green **PUSH FIRE TO START** appears under the playfield text. Press **Fire** when draw is idle to start a match (timer **01:30**, lives and fuel restored).

## Scoreboard

Pong-style **block digits** along the top:

- **Player** score on the left, **AI** score on the right (light blue)
- Center **MM:SS** countdown (packed as `MM×100+SS`; each field **0…59**, max **59:59**; match starts at **01:30**)
- Timer turns **yellow** under 0:30 and **red** under 0:10
- Scores are three digits with leading-zero blanking (**−999…999**; wrap **999 → 0**). Negative scores show a minus bar
- Under the player score: **wedge life icons** (start 3, max 5). Every **5 AI kills** grants an extra life if under the cap
- Beside the player score: a **vertical fuel bar** (**15 s** of thrust) — green, yellow at ≤10%, red at ≤5%. Empty fuel blocks thrust until respawn. The AI has unlimited lives

| Event | Player | AI | Timer |
|:-----:|:------:|:--:|:-----:|
| Your shot destroys the AI | +1 | — | +5 s |
| AI shot destroys you | — | +1 | +5 s |
| Ships crash | −1 | −1 | — |
| Hit sun / wall bounce / wrap | — | — | — |

A crash also separates the ships so it only scores once. Deaths **vanish**, then respawn (AI always; player only if lives remain). Respawn can land anywhere (including on the sun) with **1.5 s** invulnerability. Sun / black-hole kills park the ship off-screen briefly, then respawn at **zero velocity**.

Ships and shots **wrap** at the playfield edge. With a **red border** (black hole), ships **bounce** instead. The default rim is **black**.

**Game over** when the timer hits **0:00** or the player has **no lives**. Play freezes; **GAME OVER** flashes (2 Hz, 50% duty) with **PUSH FIRE TO START** below.

## How it works

**Scanout stack** (back → front): star ROM → sun / black hole → 2-bit FB ink (Diamond green, AI yellow, shots white) → HUD → **GAME OVER** / **PUSH FIRE**. HUD digit, fuel, and flash fields are latched into FFs each clock. Hyperspace tints the Diamond in scanout.

**Modules:** `sw_physics.v` (AI, gravity, shots, scores, hyperspace), `sw_draw.v` (erase / stroke), `sw_scanout.v` (LCD composite). `space_wars.v` is thin glue plus shared `sin_cos` / `fb_ram`. Shot bank: **8** slots (player 0–4, AI 5–7). Gameplay knobs: `sw_config.vh` (see **Tweaking gameplay**).

**Framebuffer:** 800×470 **2-bit** BSRAM. Full 800×480×2 does not fit in 46 BSRAM, so the bottom 10 LCD lines stay black. One playfield page only; erase/redraw while physics frames may drop if draw is busy. FB writes are FF-pipelined (1 cycle).

**Sun:** Composited in scanout (not in the FB) as an orange circle at (400, 240), radius 18, in front of ships. Hitting the sun (or black-hole / restored-sun core) **costs a player life**. After **10 shots** hit the sun it becomes a **black hole** with **1/r²** pull and a **red border**. **5 player shots** into the hole restore the sun with outward **1/r²** push for **10 s**, then gravity clears.

**Ships / fire:** Vertex outlines via `sin_cos.v`, Q8.8 positions. Mag: **5 shots / ~500 ms**, then **500 ms** reload; one shot per tap. AI bullets live at most ~**75%** of player shot life. Max speed clamp: **`CFG_SHIP_MAXV` = 10** (all modes).

**AI:** Elapsed playtime ramps range, standoff, aim, and thrust through **5:00**. Hunting uses ~**5°** heading bins (not 90° cardinal snaps), with wall and sun keep-out.

**Stars:** Constellation ROM in `star_field_rom.vh` — map **3200×470** (360°), screen shows **800** px (90°). Any-angle drift with speed 0.5×–2× (4× when off-axis). Overlay sits **under** ships and shots.

Per-frame flow (simplified): physics → collisions / sun / shots → erase old vectors → stroke ships → shot streaks.

## Source (Gowin build)

Project: [`fpga/tang20k_lcd/tang20k_lcd.gprj`](fpga/tang20k_lcd/tang20k_lcd.gprj)

| File | Role |
|:----:|:----:|
| `src/top.v` | Glue: PLL, LCD, game, buttons, DIP5 |
| `src/gowin_rpll.v` | 27 → 33 MHz rPLL |
| `src/lcd_timing.v` | 800×480 timing, border, `frame_start` |
| `src/space_wars.v` | Game glue: FB, sin_cos, handshakes |
| `src/sw_physics.v` | Physics, AI, shot bank, scores, sun/BH, HS |
| `src/sw_draw.v` | Erase / stroke ships / shots |
| `src/sw_scanout.v` | HUD, stars, sun, FB color → RGB |
| `src/sw_config.vh` | Gameplay `` `define `` knobs |
| `src/fb_ram.v` | 2-bit 800×470 BSRAM |
| `src/sin_cos.v` | Quarter-wave sine / cosine |
| `src/tang20k_lcd.cst` | Pin constraints |
| `src/tang20k_lcd.sdc` | Clock constraint |

## Build

1. Open `fpga/tang20k_lcd/tang20k_lcd.gprj` in Gowin FPGA Designer.
2. Synthesize / place & route for **GW2A-LV18PG256C8/I7**.
3. Program the Dock with **DIP1 down** and the LCD seated.

If you keep a separate Gowin tree, copy all of `fpga/tang20k_lcd/src/*.v` **and** `sw_config.vh`. Keep `sw_config.vh` on the FileList. See `docs/Gowin-copy-bsram.txt`.

## Synth snapshot (GW2A-18C)

Latest Gowin report (DIP5 + timer 59:59 + finer `want_facing`). Full **Resource Usage Summary**, utilization, clocks, Fmax, and critical-path dump: [`FPGA_Data.text`](FPGA_Data.text).

| Resource | Usage | Utilization |
|:--------:|:-----:|:-----------:|
| Logic | 19266 (14647 LUT + 4079 ALU + 90 RAM16) / 20736 | **93%** |
| Register (FF) | 2244 / 16173 | 14% |
| BSRAM | 46 / 46 | **100%** |
| DSP | 11× MULT18X18 + 5× MULTADDALU18X18 | — |
| I/O | 28 | — |
| Clock | rPLL 27 MHz → 33 MHz pixel | — |

**Timing (not met):** constrained **33 MHz**; reported Fmax **~8.0 MHz** (~127 logic levels on the pixel clock). The design **fits** and has been **board-tested**, but static timing does not close at 33 MHz — treat that as a known limit of this tree. See Path 1 in [`FPGA_Data.text`](FPGA_Data.text) (`lfsr` → `vel0_y`, slack **−94.962**).

## License

MIT — see [LICENSE](LICENSE). Demo / student project; no warranty.

</div>
