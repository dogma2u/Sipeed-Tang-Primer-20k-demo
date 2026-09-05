# Deferred / removed gameplay items

Notes for todos that are not in the current board build.

## Todo 6 — Double-buffer playfield (cancelled)

Intent: scan from page A while erase/redraw writes page B, then swap (less tear under draw load).

Math on GW2A-18 (46 BSRAM): one 800x470x2 FB is ~752k bits (~41 BSRAM). A second full page does not fit. Halving to 1-bit ink would fit two pages but drops Diamond green / AI yellow / shot ink encoding. Border is scanout-only and does not need a buffer.

Status: **cancelled**. Single FB + drop `frame_start` while `draw_busy` + FF-pipelined FB writes in `space_wars.v`.

## Todo 10 — Death segment-drift (deferred)

Intent: ~1 s breakup of ship segments that drift outward, then respawn — without flooding the framebuffer (prior expand/boom attempts failed or looked wrong).

Status: **deferred**. Current deaths are vanish + park + respawn (no X, no debris anim).

## Todo 9 — Attract demo

Done on board (both AI; Diamond hunts; timer wrap; etc.). Kept here only as historical pointer.

## Todo 11 — Nacelles

**Removed** per James — do not implement nacelle hit zones / debris.
