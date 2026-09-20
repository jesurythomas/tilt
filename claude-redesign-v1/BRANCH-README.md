# claude-redesign-v1 — branch contents

These are the redesign files produced in the cloud session on 19 Sep. **They are older
than what is currently in `src/`** — your working tree has since moved well past them
(`TiltGame.ts` 73 KB here vs 40 KB in this snapshot, `game.css` 82 KB vs 61 KB). They are
parked here as a branch so nothing is lost and you can diff against them, not because
they should replace your current work.

I could not create the branch myself: the session shell cannot mount this folder (the
8 September Windows update), so the file bridge can write files but cannot run `git`.
Claude Code on this machine is unaffected and can do it in one go.

## What's here

```
claude-redesign-v1/
  BRANCH-README.md      this file
  files/                the 14 changed files, mirroring the repo layout
    index.html
    src/styles/game.css
    src/tilt-to-live/   ArmoryUI, GameOptions, GauntletMaze, GoalsHUD, PlayerShip,
                        ProgressionManager, ScoreManager, TiltEntranceCinematic,
                        TiltGame, TiltMenu, TiltRenderer, WeaponSystem
  spec/                 the binding design spec and the four class-inventory reports
                        the stylesheet was written from
```

The snapshot is verified: `tsc --noEmit` clean, `vite build` clean, screens captured at
1440×900 and 390×844.

## Make it a branch

From the repo root, PowerShell:

```powershell
git stash -u                          # park current work if the tree is dirty
git checkout -b claude-redesign-v1

robocopy claude-redesign-v1\files . /E /NFL /NDL /NJH /NJS
git add -A
git commit -m "Claude redesign v1 (cloud session snapshot)"

git checkout -                        # back to where you were
git stash pop                         # restore parked work
```

`robocopy` returns exit code 1 on success — that is normal, not an error.

To keep the spec on the branch too, move `claude-redesign-v1/spec/` to `.redesign/`
before the `git add`.

## Diffing instead

If all you want is to see what this snapshot has that your tree doesn't:

```powershell
git diff --no-index claude-redesign-v1\files\src\tilt-to-live\TiltGame.ts src\tilt-to-live\TiltGame.ts
```

## One thing already applied

`src/tilt-to-live/GauntletMaze.ts` in your working tree **was** overwritten with the
version from this snapshot, because its timestamp showed it untouched since staging. The
only difference is three colour values on the Gauntlet wall beacons — gold `#ffd700` →
`#FFB14D` and mint `#00ffaa` → `#3DDC97`, matching the palette the rest of your tree
already uses. The pre-redesign original is at
`.pre-redesign-backup/src/tilt-to-live/GauntletMaze.ts` if you want it back.

`.pre-redesign-backup/` holds the 14 files as they were *before* the redesign, staged
26 hours ago. It is not a backup of your current work. Delete it whenever.
