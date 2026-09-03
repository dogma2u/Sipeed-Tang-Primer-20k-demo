# Changelog

All notable changes to the Sipeed Tang Primer 20K Space Wars–style demo.

## [0.2.0] — 2026-09-03

Playable match loop on the 5" LCD — starting to look like a real game.

### Added
- Center **M:SS** countdown (starts 1:30); yellow under 0:30, red under 0:10; +5 s on a shot kill
- Player **lives** (wedge icons, start 3 / max 5); bonus life every 5 AI kills; game over at 0 lives or 0:00
- Flashing red **GAME OVER** (2 Hz, 50% duty), vertically centered
- Vertical **fuel** gauge (15 s thrust); green / ≤10% yellow / ≤5% red; empty = no thrust until respawn
- **Black hole**: 10 shots into the sun → sun vanishes, soft attract gravity, red border
- Shoot the black hole **5 times** (player) → sun returns with soft **repulsion**; border white again
- Hitting sun / BH / restored-sun core costs the player a life (boom)

### Changed
- Scores render bright light blue
- Timer dimmed ~20% vs full white
- Border can switch white ↔ red with black-hole mode

### Notes
- AI still has unlimited ships; ram still −1 each; walls bounce; Gowin Education build

## [0.1.0] — earlier

- Vector Enterprise vs AI wedge, orange sun, shots, boom X, Pong-style scores, erase/redraw FB
