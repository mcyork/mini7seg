# mini7seg — hardware

The 3D-printed cover that turns four bare WS2812 digit boards into a readable
seven-segment display. Two parts printed as one: an opaque **baffle** that sits
on the PCB and gives every LED its own light well, and a translucent
**diffuser** that caps it.

## Where everything lives

| What | Where |
|---|---|
| Current model | `mini7seg_diffuser_v5.scad` |
| Build everything | `bun Build.ts` (`--digits 1` for a single-digit test piece) |
| STL / 3MF / G-code output | `out/` |
| G-code that has actually been printed | `gcode/` |
| **PCB source of truth** | EasyEDA Pro project `ProPrj_7-seg-string` (maintainer's workspace; the published design is the [OSHWLab project](https://oshwlab.com/mcyork/7-seg-string)) |

The `.epro` is a plain zip. `PCB/d97f67a54bbb46e88dcb99f7e0514d6e.epcb` is the
digit board; it is JSON-per-line. LED positions come from the `COMPONENT`
records cross-referenced to `ATTR … "Designator"`, the mount holes are the two
layer-12 `PAD` records on net GND, and the outline is the layer-11 `POLY`.
Units are **mil**; 1 mil = 0.0254 mm.

> G-code that has actually been printed lives in `gcode/`, separate from the
> generated `out/` tree, so a proven file is never confused with a fresh slice.

## Board facts, read off the PCB (mm, board-centre frame, +X right +Y up)

| | X | Y |
|---|---|---|
| LEDA | −1.778 | 10.414 |
| LEDB | 3.429 | 4.888 |
| LEDC | 3.429 | −5.334 |
| LEDD | −1.716 | −10.668 |
| LEDE | −6.985 | −5.396 |
| LEDF | −6.985 | 4.826 |
| LEDG | −1.778 | −0.254 |
| LEDDP | 7.493 | −10.414 |
| mount hole (top) | −1.778 | 5.207 |
| mount hole (bottom) | −1.905 | −5.207 |

Board **20.32 × 34.29 mm**. Mount holes drill **2.50 mm**, pad 3.50 mm, spaced
**10.414 mm**. LEDs are WS2812 "2020", body 2.0 × 2.0 mm.

**The digit is not centred on the board.** Its centreline is **x = −1.778 mm**
and its half-span is **5.207 mm**. v4 assumed 0 and 4.5, which put the left
baffle wall 2.485 mm inboard of LEDE/LEDF — the part sat on the left LEDs
instead of over them. Do not reintroduce a symmetric digit.

## Verifying a change to the model

Clearances are easy to eyeball wrong and topology is impossible to eyeball at
all. After any geometry edit, check the genus of the baffle:

```
openscad -o /tmp/g.stl -D 'mode="baffle"' -D digit_count=4 mini7seg_diffuser_v5.scad
```

**One component, and genus = 8 × digits** (one handle per light well: 7
segments + DP). 1 digit → 8, 2 → 16, 4 → 32.

This is not academic. The inter-digit bridges originally anchored on a computed
silhouette extent that measured the wrong thing — `digit_silhouette()` hulls
the top and bottom cells separately, so at the waist the outline pinches to
3.443 mm, not the 6.029 the formula predicted. The bridges started 1.086 mm
outside the digits they were meant to join and touched at two 0.164 mm slivers:
a 1.3 mm² weld where 10 mm² was intended. It rendered, it sliced, it looked
correct in preview, and it would have snapped apart in your hand. The **only**
signal was genus 38 where 32 was correct — two spurious handles per bridge.

The fix was to run the bridge centre-to-centre and subtract the pockets *after*
unioning the bridges, so the outline never has to be known.

## Assembly

The posts are **not** snap-fit. They pass through the 2.50 mm holes and stand
1.6 mm proud underneath; flatten that stub with a soldering iron to form a
rivet over the 3.50 mm pad. There is no way to get the part off again
afterwards, so dry-fit first.

## Printing

The part prints **upside down** — clear face on the bed, posts pointing up.
Printed the other way the posts would have to grow downward into the bed.
So the print order is clear first, then black, which is the opposite of how the
finished part reads in the hand.

Two routes out of `Build.ts`:

- `out/v5-4d-colourchange.3mf` — **preferred.** Both volumes on one extruder
  with an `M600` baked in at z = 1.8. One filament swap, no MMU, no purge
  tower, no waste. Runs on any MK4S.
- `out/v5-4d-2colour.3mf` — MMU3, clear on tool 3 and black on tool 2.

### ⚠ PrusaSlicer gotchas, both learned the hard way

1. **CLI + MK4S MMU3 + a genuinely two-tool object segfaults** (exit 139) at
   "89 => Calculating overhanging perimeters", during wipe-tower generation.
   It is not the file — the previously GUI-sliced `v4-4d-2colour.3mf` crashes
   identically. `--wipe-tower=0` is the only CLI workaround; otherwise slice in
   the GUI. This is the reason the colour-change route is preferred.
2. **`--colorprint-heights` is accepted and then silently ignored.** It writes
   `M600` into the config footer and emits none in the print body, so the file
   looks fine and prints in one colour. Colour changes must be baked into the
   3MF as `Metadata/Prusa_Slicer_custom_gcode_per_print_z.xml`, which is what
   `Build.ts` does. Always verify with `--binary-gcode=0` and grep for a
   line-start `M600`.
3. Output is **binary** G-code regardless of the `.gcode` extension unless you
   pass `--binary-gcode=0`. Grepping a `.gcode` file that starts with `GCDE`
   will find nothing and tell you nothing.
