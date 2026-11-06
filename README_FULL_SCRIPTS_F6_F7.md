# BO2 complete script replacements — F6 / F7 / ESP

This branch contains the **complete replacement source files**, not a patch.

## Files
- `zm_bo2_bots.gsc` — full bot script with one-press F6/F7 commands.
- `zm_modmenu.gsc` — full menu script with faster input and hollow ESP frames.
- `zm_bo2_bots_combat.gsc` — unchanged original dependency; keep it installed.

## Controls
- **F6** — cycle the shared bot mode: Stay → Wander → Wander Further → Follow → Stay.
- **F7** — teleport all bots to your position (you must be on the ground).
- The mod menu still uses Action Slot 1/2 to scroll, Jump to select, and Melee to go back.

## Install
1. Back up the current versions of `zm_bo2_bots.gsc` and `zm_modmenu.gsc`.
2. Copy both complete files from this branch into:
   `%localappdata%\Plutonium\storage\t6\scripts\zm\`
3. Keep `zm_bo2_bots_combat.gsc` in the same `scripts\zm` folder.
4. Open `%localappdata%\Plutonium\storage\t6\players\bindings_zm.bdg` and add the two lines from `bindings_f6_f7_zm.bdg` **above** `unbindallaxis`. Do not replace the existing bindings file.
5. Start a new Zombies match, or run `map_restart` from the console.

## ESP / performance
- ESP shows the four nearest zombies using four thin waypoint bars per target (an empty outline rather than a solid square).
- The frame is offset upward from `j_head` so the head remains visible.
- Menu polling is 25 ms; scroll repeat delay is 80 ms and selection delay is 150 ms.

## Validation
Both full source files passed balanced-brace and exact-handler checks. The game itself is not available in this environment, so visual positioning and in-match input still need to be verified in a private match.
