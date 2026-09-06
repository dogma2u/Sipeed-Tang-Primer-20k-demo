# Local restore point (before todos 6 / 7 / 12)

Created before implementing secret green sun, anti-grav timeout, and wrap/no-white-border.

## How to restore

From repo root (this tree):

```
git checkout restore/pre-todos-6-7-12 -- fpga/tang20k_lcd/src/
```

Or reset the working branch tip to that commit (only if you intend to discard later commits on the branch):

```
git checkout restore/pre-todos-6-7-12
```

Commit at restore: see `git rev-parse restore/pre-todos-6-7-12` (was `ddac2bf` when created).

This branch is **local** unless you push it. Do not push unless asked.
