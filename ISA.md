---
project: mini7seg
task: DIY-configurable display geometry plus a visual segment editor
effort: E3
phase: verify
progress: 38/55
mode: algorithm
started: 2026-09-21
updated: 2026-09-21
---

# mini7seg — ISA

## Problem

The firmware assumes one display: four digits, one LED per segment, a decimal
point on every digit, wired in the exact order A,B,C,D,E,F,G,DP. That assumption
is not a variable — it is spread across `#define DIGITS 4`, `NUM_LEDS (DIGITS*8)`,
and, decisively, a formula inside the library:

```cpp
ledIndex = _offset + position*8*_ledsPerSegment + seg*_ledsPerSegment + led;
```

A formula can only express wirings that are arithmetic. Someone hand-soldering a
WS2812 strip routes it in whatever order the physical layout made convenient, so
their build is almost never arithmetic. The library's README states the required
order as a *contract on the builder*, and ships a `segment_test` example whose
purpose is to help them discover their own wiring so they can **rewire to match
the library**. The burden is on the wrong side.

`numDigits` and `ledsPerSegment` already exist as constructor arguments. The
missing piece is the one that cannot be a number: the order.

## Vision

A builder finishes soldering, flashes the firmware, opens the settings page and
sees a drawing of a seven-segment display. They press Learn. One LED lights on
their bench; the page asks which segment just lit; they tap it on the drawing.
The drawing fills in as they go. At the end, their clock works — and at no point
were they asked for a fact about their own wiring that they did not have.

The euphoric surprise is the inversion: you do not describe the display to the
firmware, the firmware describes itself to you and you confirm.

## Out of Scope

Not doing: multiplexed or charlieplexed displays (this is addressable-strip
only); non-seven-segment layouts such as fourteen- or sixteen-segment; RGBW
pixels; more than one physical strip / data pin; per-segment colour calibration;
auto-detection of wiring without human confirmation (there is no sense path back
from the LEDs). Not changing the character font or the segment bit assignments —
`SEG_A..SEG_DP` stay as they are, because the table expresses the physical
wiring so the logical order never needs to move. Not rewriting the library's
formula in place; the firmware maps, the library keeps its simple default for
users who did follow the wiring contract.

## Principles

- **The map is the truth; the numbers are a compression of it.** `digits`,
  `ledsPerSeg` and `dpMask` describe only the regular subset. They stay because
  they make the common case one click, never because they are sufficient.
- **Never ask for knowledge the user does not have.** A configuration question
  the builder cannot answer is a defect, not a form field.
- **A formula is a constraint; a table is a capability.** Replacing one with the
  other changes what is expressible, which is why it outranks any parameter.
- **Default behaviour is sacred.** An existing device that updates must come up
  identical, with no action from its owner.

## Constraints

- FastLED takes the LED **count** at runtime but the **pin** as a template
  parameter; the count is free, the pin is not (already solved via PIN_XLIST).
- Flash sits at ~70% of a 1.92 MB OTA slot. The UI must stay small.
- Served pages must be pure ASCII and declare UTF-8 — a mojibake defect was just
  fixed and must not return.
- NVS must migrate silently: no stored geometry means defaults, not a blank panel.
- Single source of truth for any list with two consumers, per the PIN_XLIST
  precedent in `settings.h`.
- One data pin, one strip, MAX_DIGITS 8, MAX_LEDS 512.

## Goal

Make display geometry fully runtime-configurable via a per-segment LED index
table stored in NVS, render everything through that table instead of the
positional formula, and ship a visual seven-segment editor whose Learn wizard
builds the table empirically by lighting one LED group at a time — with the
shipped defaults reproducing today's four-digit behaviour byte for byte.

## Criteria

### Geometry model
- [x] ISC-1: `Settings.digits` exists, range 1..8 enforced
- [x] ISC-2: `Settings.ledsPerSeg` exists, range 1..8 enforced
- [x] ISC-3: `Settings.dpMask` exists, bit d = digit d has a physical decimal point
- [x] ISC-4: `uint16_t segBase[MAX_DIGITS][8]` table exists in Settings
- [x] ISC-5: SEGMENT_ABSENT (0xFFFF) means "segment absent", skipped, never written
- [x] ISC-6: LED buffer is MAX_LEDS 512 static, RAM stays under 25%
- [x] ISC-7: `geometryReset()` packs a running counter striding by `ledsPerSeg`
- [x] ISC-8: Defaults are digits=4, ledsPerSeg=1, dpMask=0x0F
- [x] ISC-9: Geometry blob round-trips through NVS unchanged
- [x] ISC-10: A device with no stored geometry boots with the defaults
- [x] ISC-11: FastLED receives runtime count `digits*8*ledsPerSeg`

### Rendering through the table
- [DEFERRED-VERIFY] ISC-12: `renderDigit(pos, mask, colour)` walks segBase, not the formula
- [DEFERRED-VERIFY] ISC-13: Clock display renders via renderDigit
- [DEFERRED-VERIFY] ISC-14: Ticker (BTC + temp) renders via renderDigit
- [DEFERRED-VERIFY] ISC-15: Seconds overlay indexes via the table, not `d*8+k`
- [DEFERRED-VERIFY] ISC-16: `String7Segment::getPattern(char)` still supplies char->mask
- [DEFERRED-VERIFY] ISC-17: Decimal point respects dpMask (absent DP never written)

### Validation
- [x] ISC-18: Index >= MAX_LEDS rejected with a naming error
- [x] ISC-19: Duplicate index anywhere in the table rejected
- [x] ISC-20: digits out of range rejected
- [x] ISC-21: ledsPerSeg out of range rejected
- [x] ISC-22: Error response names the specific problem, not a generic failure

### Endpoints
- [x] ISC-23: GET /geometry returns {digits,ledsPerSeg,dpMask,segBase}
- [x] ISC-24: /setgeometry applies a full flat table
- [x] ISC-25: Geometry change takes effect with NO reboot
- [x] ISC-26: /identify?d=&s= lights only that segment
- [x] ISC-27: /probe?i=N lights only LED group N
- [x] ISC-28: /probe?i=-1 clears
- [DEFERRED-VERIFY] ISC-29: Clock resumes on its own after identify/probe

### Visual editor
- [x] ISC-30: SVG renders `digits` digits live from /geometry
- [x] ISC-31: Segments drawn as tapered seven-segment polygons, not rectangles
- [x] ISC-32: Decimal point dot appears only on digits set in dpMask
- [DEFERRED-VERIFY] ISC-33: Clicking a segment calls /identify
- [DEFERRED-VERIFY] ISC-34: Clicked segment highlights during the request
- [x] ISC-35: Learn wizard steps groups 0..N-1 calling /probe
- [x] ISC-36: Clicking a segment during Learn records `segBase[d][s] = i*ledsPerSeg`
- [x] ISC-37: Wizard Skip marks a group unused and advances
- [x] ISC-38: Wizard Back returns one step
- [x] ISC-39: Assigned segments render differently from unassigned
- [DEFERRED-VERIFY] ISC-40: Wizard submits the assembled table and shows the response
- [x] ISC-41: digits / ledsPerSeg / dpMask controls live-update the SVG
- [DEFERRED-VERIFY] ISC-42: "Reset to standard wiring" button restores the formula table
- [DEFERRED-VERIFY] ISC-43: Page renders legibly at 400px width

### Anti-criteria
- [DEFERRED-VERIFY] ISC-44: Anti: an existing 4-digit device must NOT change behaviour on update
- [x] ISC-45: Anti: geometry change must NOT require a reboot
- [x] ISC-46: Anti: no external scripts, styles, fonts or images
- [x] ISC-47: Anti: no non-ASCII bytes in any served page
- [x] ISC-48: Anti: clock, ticker, seconds overlay and pin selector must NOT regress

### Wiring mode owns the panel (added after first bench use)
- [x] ISC-50: Clock paints ZERO frames while a wiring preview is latched
- [x] ISC-51: A preview latches until changed or cleared -- no expiry
- [x] ISC-52: Ticker is suppressed while wiring owns the panel
- [DEFERRED-VERIFY] ISC-53: Idle watchdog releases the panel after 5 min of page silence
- [DEFERRED-VERIFY] ISC-54: Page heartbeat refreshes the latch every 2 min while open
- [DEFERRED-VERIFY] ISC-55: pagehide releases the latch so a closed tab resumes the clock

### Antecedent
- [DEFERRED-VERIFY] ISC-49: Antecedent: the builder is never asked a fact about their own wiring

## Test Strategy

| isc | type | check | threshold | tool |
|---|---|---|---|---|
| 1-8 | static | grep struct + range guards in /setgeometry | present | Grep |
| 9-10 | runtime | erase NVS, boot, read /geometry | defaults | curl |
| 11 | static | addLeds count arg is computed | non-literal | Grep |
| 12-17 | runtime | set a scrambled table, photograph digits | correct glyphs | eyes + curl |
| 18-22 | runtime | post bad payloads, read error strings | named errors | curl |
| 23-29 | runtime | hit each endpoint, observe panel | expected LEDs | curl |
| 30-43 | UI | load page, screenshot, click through wizard | renders + advances | Interceptor |
| 44 | runtime | update existing device, compare display | identical | eyes |
| 45 | runtime | change geometry, no restart, observe | immediate | curl |
| 46-47 | static | grep for http/src= and non-ASCII bytes | zero | Grep |
| 48 | runtime | clock/ticker/seconds/pin all still work | all pass | curl |
| 49 | experiential | complete a wizard run knowing nothing | completes | manual |

## Features

| name | satisfies | depends_on | parallelizable |
|---|---|---|---|
| geometry-model | ISC-1..11 | - | yes |
| render-through-table | ISC-12..17 | geometry-model | no |
| validation | ISC-18..22 | geometry-model | yes |
| endpoints | ISC-23..29 | render-through-table | no |
| svg-editor | ISC-30..34, 41-43 | endpoints | yes |
| learn-wizard | ISC-35..40, 49 | svg-editor | no |
| regression-guard | ISC-44..48 | all | no |

## Decisions

- 2026-09-21: Table over formula. A formula expresses only arithmetic wirings;
  hand-built displays are rarely arithmetic. Cost is digits*8 bytes.
- 2026-09-21: Map in the FIRMWARE, not by editing the library. Users who did
  follow the wiring contract keep the simple library default; the firmware owns
  the general case. Avoids a breaking change to a published library.
- 2026-09-21: Logical segment order stays A..DP. The table expresses physical
  wiring, so there is no second place where order can disagree.
- 2026-09-21: Learn wizard chosen over a numeric form, drag-assign, or photo-tap,
  scored on "what must the builder already know". Wizard is the only one whose
  answer is nothing.
- 2026-09-21: Version bumps per change; GitHub Releases only at real milestones.
  The device self-updates and has no rollback, so a release is a push to every
  unit. This work lands as 1.1.0 and becomes the first honest end-to-end OTA test.

## Verification

ISC-1..11: curl /geometry -- {"digits":4,"ledsPerSeg":1,"dpMask":15,segBase 0..31 then 65535 rows}
ISC-9/10: geometry absent from NVS on a 1.0.0 device; booted to exactly the defaults above
ISC-18: curl /setgeometry segBase=...,250 with 8 active LEDs -> "run exceeds active LED count"
ISC-19: two segments on LED 0 -> "segBase[1][0] run overlaps LED 0" (run overlap, not base equality)
ISC-20/21/22: digits=99 -> "digits must be 1..8"; each failure names the field or cell
ISC-23/24: 6 digits @ 2 LEDs/seg, DP on digits 1+3 only -> accepted, read back identical,
           packing correct (d0 has no DP so d1 starts at 14; d1 has one so d2 starts at 30)
ISC-25: every /setgeometry above took effect with no restart
ISC-26/27/28: /identify and /probe return ok; /probe?i=-1 -> {"ok":true,"mode":"off"}
ISC-30/31/32: interceptor eval on the live page -- viewBox "0 0 400 178", 28 polygons,
           4 circles, 32 assigned; first polygon "6,13 13,6 71,6 78,13 71,20 13,20" (chamfered)
ISC-35..39: drove the wizard in real Chrome -- "Group 0 of 32 is lit", two segment clicks
           advanced to Group 2 with assigned=1 then 2, Skip -> Group 3, Back -> Group 2
ISC-46/47: served page has 0 non-ASCII bytes and 0 external references
ISC-48: /api still returns time, pin, hue, secpath, cards after all of the above

Deferred, with reasons:
  T1 -- needs a hand-wired display on the bench. Only the standard 4-digit PCB exists here,
        on which a correct table and the old formula are indistinguishable by eye. The probe
        is real but the hardware to make it meaningful does not exist yet.
  T2 -- 400px render unverified: interceptor screenshot capture path is wedged (Doctor says
        HEALTHY, roundtrip OK; capture times out at 15s, twice). Known skill gotcha.
  T3 -- ISC-44 needs the pre-update device to compare against; it has already been updated.

## Changelog

conjectured: painting the preview into the buffer is enough to show one segment
refuted_by: Ian on the bench -- the clock was still running underneath, so the
  preview was overdrawn five times a second and read as a blip on top of a live
  clock. Measured after the fix: 46 clock paints per 15 s before, 0 while latched,
  53 after release.
learned: "show X instead of Y" is a claim about what STOPS, not only about what
  starts. showTime() was reached from three call sites and guarding them one at a
  time is how the miss happened; one refusal inside showTime() covers every caller
  including ones added later.
criterion_now: ISC-50 counts clock frames during a latch and requires exactly zero

conjectured: a 1500 ms identify pulse is long enough to see
refuted_by: the builder is looking at the bench, not the screen, and a timed pulse
  makes "which segment lit up?" a question about reaction time
learned: any prompt that asks the user to observe hardware must latch until they
  answer; the timeout then has to move to a watchdog, because a latch with no
  release strands the device when the tab closes
criterion_now: ISC-51 latches, ISC-53 bounds it with a 5 min idle release

conjectured: a per-segment base table indexed d*8+s would express any DIY wiring
refuted_by: the table stores each segment's FIRST led, so consecutive segments sit
  ledsPerSeg apart -- d*8+s only holds when ledsPerSeg is 1, and silently overlaps
  every segment onto its neighbours above that. Caught because the independently
  built UI derived a packed counter scaled by ledsPerSeg and the two disagreed.
learned: when two components must agree on a derived layout, building them from the
  same prose spec independently is a cheap differential test -- the disagreement is
  the signal, and it found a bug that compiles, flashes and looks plausible.
criterion_now: ISC-7 asserts the packed running counter, not the stride-by-8 formula

conjectured: uint8_t is enough for a segment base index
refuted_by: 255 is spent on the sentinel, capping the table at 255 LEDs while the
  buffer is 512 -- and after widening to uint16_t, a surviving `uint8_t base = ...`
  local truncated 0xFFFF to 0xFF so every absent-segment check failed on hardware
learned: widening a stored type is not done until every local that reads it is
  widened too; the compiler warns on neither, and the failure only appears at the
  sentinel value, which is exactly the case a happy-path test never sends
criterion_now: ISC-5 is probed with a real 65535 round-trip, not by inspection
