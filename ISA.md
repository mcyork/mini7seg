---
project: mini7seg
task: Production-readiness audit of the ntp4digit firmware and the mini7seg repo
effort: E3
phase: complete
progress: 62/124
mode: research
started: 2026-09-21
updated: 2026-09-23T08:20:00-07:00
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

### Production readiness (audit opened 2026-09-23)

Build and reproducibility
- [x] ISC-56: `pio run` compiles the firmware with zero warnings from project sources
- [x] ISC-57: `platform` and every `lib_deps` entry in platformio.ini are pinned to exact versions
- [ ] ISC-58: All six library examples compile for an ESP32 target
- [x] ISC-59: A CI workflow builds the firmware and the examples on every push

Versioning and release
- [ ] ISC-60: library.properties `version` and library.json `version` are the same string (refined 2026-09-23: firmware and library version independently)
- [ ] ISC-61: library.json `name` and `repository.url` match the published repo (Mini7Seg, mcyork/mini7seg)
- [ ] ISC-62: A git tag `v<FW_VERSION>` exists on the commit the release binary was built from
- [ ] ISC-63: GH_REPO in main.cpp names a repo whose latest release carries `firmware.bin` built from the current code
- [x] ISC-64: One command builds, tags, and publishes the release (script in the repo, no manual steps)
- [x] ISC-65: `/checkupdate` on the live device returns `ok:true` with a `latest` tag

OTA and recovery
- [ ] ISC-66: The firmware download verifies the server certificate (no `setInsecure()` on the update path)
- [ ] ISC-67: Three consecutive crash resets roll the device back to the previous OTA slot
- [ ] ISC-68: `/doupdate`, `/stress` and `/reboot` reject GET (no side effects reachable by a prefetch)
- [x] ISC-69: README states the trust model of the update endpoints (LAN-open, no auth) in one sentence

Firmware robustness
- [ ] ISC-70: With NTP unreachable, `/api` still answers within 1 s (syncTime backs off instead of blocking every loop)
- [ ] ISC-71: `previewGroup` is 16-bit; `/probe?i=300` on a 512-LED strip lights LED 300
- [ ] ISC-72: `/api` JSON stays valid when `city` contains a double quote or exceeds 100 chars
- [ ] ISC-73: The router sees the DHCP hostname `mini7seg` (`WiFi.setHostname` before `begin`)
- [ ] ISC-74: `ArduinoOTA.begin()` runs at most once per online transition (guarded like mDNS)
- [ ] ISC-75: A slider drag writes NVS at most once per 2 s (save is debounced, not per event)
- [ ] ISC-76: Saving an SSID with an empty password clears any previously stored password
- [ ] ISC-77: Timezone is a runtime setting on the settings page, not a compile-time constant
- [x] ISC-78: No stale comments: main.cpp header ("no OTA", arduino-cli build lines) and platformio.ini ("740 MB") corrected

Web UI
- [ ] ISC-79: The wiring page shows the firmware's rejection text (reads `error`, not `err`)
- [ ] ISC-80: "Check for updates" distinguishes "no release published" from "GitHub unreachable"
- [ ] ISC-81: A fetched temperature of 0 F renders as 0 F, not "temp not fetched"
- [x] ISC-82: Settings and wiring pages render legibly at 400 px (Interceptor screenshot)
- [ ] ISC-83: Outside portal mode an unknown path returns 404, not the settings page with 200

Library
- [ ] ISC-84: `BG_BLEND` is implemented, or removed from the header, keywords.txt and README
- [ ] ISC-85: The S7Color comment names the real collision (FastLED's CRGB), not "S7Color"
- [x] ISC-86: README's examples table lists `mixed_strip`
- [ ] ISC-87: README states that the library does no bounds checking on the caller's LED array

Docs and repo hygiene
- [x] ISC-88: README has a firmware section: what ntp4digit is, how to flash, the web UI, OTA, the wiring wizard
- [x] ISC-89: README links the hardware directory (enclosure, diffuser, PCB source)
- [x] ISC-90: BUILD.md describes the PlatformIO build for the C3 (not arduino-cli for an S3) and is not in .gitignore
- [x] ISC-91: No personal paths in tracked files (iCloud path, rail-end-cap note, `~/.platformio` absolute paths)
- [x] ISC-92: The relationship between mcyork/mini7seg and mcyork/7segclock is written down (which is canonical, why two)
- [x] ISC-93: GitHub description and topics mention the clock firmware, not only the library

Anti-criteria
- [ ] ISC-94: Anti: an existing 4-digit device keeps every NVS setting across the next OTA update
- [ ] ISC-95: Anti: no change from this audit alters display rendering (geometry, colours, seconds overlay)
- [x] ISC-96: Anti: no token or credential lands in the repo (release tooling uses `gh` auth)

Added by IterativeDepth (Literal + Failure lenses)
- [ ] ISC-97: `docs/firmware.factory.bin` in 7segclock and the latest release `firmware.bin` carry the same FW_VERSION
- [x] ISC-98: The installer page pins `esp-web-tools` to an exact version (not a floating `@10`)
- [x] ISC-99: The firmware has one source: 7segclock/src and mini7seg/firmware/ntp4digit/src are byte-identical, or one is removed
- [x] ISC-100: Anti: `/checkupdate` never reports `newer:true` for a tag equal to or lower than FW_VERSION

Added after the Advisor call
- [x] ISC-101: The release contract the 1.0.0 updater depends on is written down: tag `vX.Y.Z`, asset named `firmware.bin`, repo `mcyork/7segclock`
- [x] ISC-102: Whether app rollback needs `CONFIG_BOOTLOADER_APP_ROLLBACK_ENABLE` (bootloader, not OTA-deliverable) is settled with evidence
- [ ] ISC-103: A GitHub 403 (rate limit) on `/checkupdate` is reported as such, not as "unreachable"
- [x] ISC-104: Every `millis()` interval comparison is subtraction-based (rollover-safe at 49.7 days)
- [ ] ISC-105: No state-changing endpoint is reachable from an `<img src>` on another LAN page (POST or token on `/set`, `/setgeometry`, `/probe`, `/identify`, `/stress`, `/doupdate`, `/reboot`)

Added from the audit fleet and Forge (2026-09-23)
- [x] ISC-106: The installer image `docs/firmware.factory.bin` contains the self-updater (`strings` finds `checkupdate` and `api.github.com`)
- [ ] ISC-107: `/doupdate` re-checks GitHub and refuses unless `latest` is strictly newer than FW_VERSION (no downgrade by request)
- [ ] ISC-108: `/doupdate` downloads the tag it verified (`releases/download/<tag>/firmware.bin`), not whatever `latest` resolves to at flash time
- [ ] ISC-109: The release tag points at the commit whose `src/main.cpp` carries that FW_VERSION (`git show <tag>:src/main.cpp`)
- [ ] ISC-110: A successful `/setgeometry` is reported as saved on the wiring page (success JSON carries `ok:true` or the page tests for `error`)
- [ ] ISC-111: Turning a decimal point off on the wiring page saves (the page sends `65535` for `segBase[d][7]` when the dpMask bit is clear)
- [ ] ISC-112: Changing LEDs-per-segment on the wiring page saves (the table is rescaled before it is sent)
- [ ] ISC-113: A cold boot with saved credentials and the router down does not raise the setup AP (same 10-minute grace as a drop)
- [ ] ISC-114: While the portal is up and the time is known, the panel still shows the time
- [ ] ISC-115: An aborted browser upload does not block the next upload until reboot (`UPLOAD_FILE_ABORTED` calls `Update.abort()`)
- [ ] ISC-116: `/stress` does not call `server.handleClient()` from inside its own handler (re-entrant handlers)
- [ ] ISC-117: `String7Segment::showNumber` shows the minus sign with `leadingZeros`, keeps it for over-wide values, and is INT32_MIN-safe
- [ ] ISC-118: Every library example compiles for `esp32-c3-devkitm-1` (`mixed_strip` uses `S7Color`, no example hard-codes a pin the C3 lacks)
- [x] ISC-119: 7segclock has a LICENSE file matching the MIT claim in its README
- [ ] ISC-120: Geolocation runs on any online transition while lat/lon are unset, and `city` is persisted

Added from the completeness critic (verified by hand after the agent quota ran out)
- [ ] ISC-121: The clock face follows `cfg.digits`: 6+ digits show HH:MM:SS, 4 show HH:MM, fewer show a truthful subset (today `d[4]` and `shown=min(4,digits)` leave extra digits dark)
- [ ] ISC-122: An HTTP request is answered within ~20 ms of connect, not after the loop's fixed `delay(200)` (measured 192–208 ms first-byte)
- [ ] ISC-123: The six-hourly resync only stamps `lastSyncMs` on a real SNTP completion (today `getLocalTime()` succeeds instantly because the clock is already set, so a later NTP block drifts silently)
- [ ] ISC-124: The settings page can change WiFi credentials and factory-reset without waiting out a 10-minute outage

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
| 56-58 | build | `pio run`, `pio ci` per example | 0 warnings, all build | Bash |
| 59 | static | `.github/workflows/*.yml` exists and last run green | green | gh |
| 60-61 | static | grep the three version strings and library.json fields | identical | Grep |
| 62-65 | runtime | `git tag`, `gh release view`, `curl /checkupdate` | tag + asset + ok:true | Bash, curl |
| 66-68 | static+runtime | grep setInsecure on update path; `curl -X GET /doupdate` | absent; 405 | Grep, curl |
| 69, 84-93 | static | read README / BUILD.md / manifests | statement present | Read |
| 70-76 | runtime | break NTP, probe /api; /probe?i=300; inject quote into city | as stated | curl |
| 77 | UI | settings page shows a timezone control | present | Interceptor |
| 79-83 | UI+runtime | reject a geometry, read page text; curl unknown path | error text; 404 | Interceptor, curl |
| 94-96 | runtime+static | dump /api before and after update; grep for tokens | identical; none | curl, Grep |

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
| audit-findings | ISC-56..96 (report which pass and which fail, with evidence) | - | yes |
| release-pipeline | ISC-57, 59, 60-65, 96 | audit-findings | yes |
| ota-hardening | ISC-66..69 | audit-findings | yes |
| firmware-fixes | ISC-70..78, 94, 95 | audit-findings | yes |
| ui-fixes | ISC-79..83 | audit-findings | yes |
| library-and-docs | ISC-84..93 | audit-findings | yes |

## Parked — design space, not commitments

⚠ Working notes. Deliberately NOT in any README: this is us thinking, and most
of it should stay unbuilt until something forces it.

**The shape of the whole question.** Four of these are one question wearing four
hats. The model today is `digit x segment -> LED base` with a single global run
length. Each idea breaks a different assumption inside that sentence:

| idea | assumption it breaks | status |
|---|---|---|
| spare LEDs between segments | "the strip IS the segments" | FIXED (stripLen) |
| a ":" in the display | "every element is a digit segment" | open |
| uneven segment sizes | "one global run length" | open |
| 5-6 digits, shift/seconds | "geometry decides content" | open |

The general form is: **a display is a list of ELEMENTS; an element is a ROLE plus
a SET of LED indices.** Roles: digit-segment(d,s), colon, dot, decoration.
`segBase[d][s]` + `ledsPerSeg` is a compression of exactly that — which makes
this the same move as formula->table, one level up. Worth noticing before
building anything: we have now been wrong twice in the same direction, both times
by keeping a compression after it stopped fitting.

**Cheapest real win: per-segment length.** `segLen[d][s]`, uint8, 64 bytes.
Subsumes global `ledsPerSeg` (which becomes what Reset fills in). Unblocks uneven
segments with no new concepts and no new UI mode — the wizard already asks
per segment, so it can just count how many groups you assign to one.

**Colon: resist the full element list.** A real clock wants at most two colons
(HH:MM:SS). `colonBase[2]` + `colonLen[2]` covers the actual case for ~8 bytes.
A general element list is the right ABSTRACTION and the wrong amount of work for
one punctuation mark. Revisit if a third role ever shows up.

**5/6 digits is not a geometry problem.** "Shift left/right" and "show seconds"
are LAYOUT: which digits the clock occupies and what it renders into them. Wants
`layout` (auto | HHMM | HHMMSS) + `firstDigit`, independent of the table. Keeping
them separate matters — conflating them is how you end up unable to put a 4-digit
clock on the right half of a 6-digit display.

**Streaming to/from another MCU: do not invent a protocol.** sACN (E1.31) and DDP
are what WLED, xLights, Hyperion and Falcon already speak. Output mode = we emit
our frame so another controller extends the display in sync; input mode = we
become a dumb pixel driver someone else sequences. A UDP socket and a packet
header buys interoperability with an entire ecosystem. Note the physical version
needs no protocol at all: the last pixel's DO already chains onward, so "more
LEDs" is just a bigger stripLen.

**Last LED's DO wired back to a GPIO: the best idea here, and it is real.**
WS2812 pixels consume the first 24 bits and forward the rest, so a chain of N
pixels re-emits frame N+1 on its DO. Wire that back and:
  - send N+1 frames, watch for the echo -> the chain is intact end to end
  - binary search the frame count -> the largest N that echoes IS the LED count
  - a mid-chain break stops the echo, and the search locates it
That auto-detects the number the wizard currently has to ask for, and turns
"is my display connected" into a probe instead of a guess.
Feasible on a C3: RMT has a receive mode at ~12.5 ns resolution against WS2812's
1.25 us bit, so the echo is comfortably sampleable. RMT TX out, RMT RX back.
⚠ HARDWARE HAZARD: DO swings to the pixel's VDD. On a 5 V strip that is a 5 V
signal into a pin that is 3.3 V tolerant and NOT 5 V tolerant. It needs a divider
or a series resistor, and getting this wrong kills the GPIO. Next board revision,
alongside the parked ambient-light idea — not a bodge on the current one.

## Parked — generalising past LEDs, and the connector post-mortem

⚠ Still working notes, still not README material.

### CORRECTION - three of my "constraints" were ours, not physics

Ian, 2026-09-21: *"You have to think more broadly when I say crazy. It means
revisit or remove prior constraints."* Right on all three, and the pattern is
worth keeping because it is the same error each time - **treating a decision we
own as a law we obey.**

| I called it | what it actually is |
|---|---|
| `uint8_t getPattern` is a HARD BLOCKER for alpha | our own library. Bump the major, widen to uint16/32. Consumers pin versions; that is what versions are FOR. |
| the 7.2 mm cavity rules out connectors | a variable in an unfinished SCAD file we control. I used an **unbuilt case** to eliminate a **physical board feature** - backwards, since the board outlives the case. |
| the chaining edge has only 1.667 mm | true, and irrelevant. Connectors go on the **back face**: 20.32 x 34.29 minus two mount holes, nearly all free. |

And the one underneath those: **I assumed boards must butt.** Pitch = board width
was an observation I promoted to a requirement. With cables, digit pitch is free.

### What removing "must butt" actually buys

Spacing stops being 20.32 mm and becomes a choice: gaps for a colon, grouping
(HH MM), non-linear layouts, grids assembled from row-shaped boards, digits on
different planes or a curve. The display stops being a strip of digits and
becomes an arrangement.

Note what that does NOT require: the firmware already handles it. The segment
table and the Learn wizard never assumed a row, a pitch, or adjacency - they map
LED indices to elements and ask the human what they see. **The firmware is
already ahead of the hardware**, which is the argument for freeing the board.

### Populate-by-choice is the answer, not a compromise

Both footprints. Castellations L/R for dense butted runs - zero height, zero BOM,
zero cable. 2x JST-SH 3-pin on the back for spaced or flexible runs. Footprints
cost nothing on a fab panel; population is a build-time decision. Ordinary
practice, not a hedge.

### The constraint that IS physics: power through the chain

Measured figure already in the firmware: 60 mA per LED at full white, so 480 mA
per 8-LED digit. Current through the FIRST connector of a chain:

| digits | full white |
|---|---|
| 2 | 0.96 A |
| 4 | **1.92 A** |
| 8 | 3.84 A |

JST-SH contacts are rated about **1 A**, so a 3-pin JST daisy-chain is over spec
past roughly **two digits at full white** - the existing 4-digit panel already
draws about twice a single contact's rating if allowed to run white. It works
today only because setMaxPowerInVoltsAndMilliamps caps it:

| brightness | per digit | digits per 1 A contact |
|---|---|---|
| 40 (16%) | 75 mA | 13.3 |
| 128 (50%) | 241 mA | 4.2 |
| 255 (100%) | 480 mA | 2.1 |

**Consequence:** carrying power through the same 3-pin chain is what does not
scale, independent of which connector we pick - it is contact area. Fix is
standard strip practice: **two power-injection pads on the back of every board**,
so 5 V and GND can be fed anywhere in the run and the chain connector carries
data plus only local current. That is the one addition worth making
unconditional; everything else is populate-by-choice.

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
- 2026-09-23 01:25: Audit result: 7 of 65 production criteria pass. Fix batching adopted from the
  Advisor: A = repo-only (installer image, pins, release script, CI, docs), B = one firmware
  release 1.2.0 verified through the real 1.0.0 -> 1.2.0 hop on a spare board, C = library 1.1.0.
  Nothing applied; awaiting Ian on canonical repo, batch approvals, hostname suffix.
- 2026-09-23 01:25: refined: ISC-60 no longer ties FW_VERSION to the library version (Forge:
  they version independently); it now requires only that the two library manifests agree.
- 2026-09-23 01:25: ❌ DEAD END: my first read of `docs/firmware.factory.bin` matched the string
  "1.1.0" and I recorded the installer as current. Wrong: that string is not FW_VERSION; the
  image has no updater at all. A version string is not a version — grep for a feature symbol.
- 2026-09-23 00:55: Advisor (Inference.ts) before the fan-out: the 1.0.0 updater in the field is a frozen
  contract (tag format, asset name, repo); rollback may need a bootloader flag OTA cannot deliver;
  GET endpoints are a CSRF surface for any LAN page; split fixes by blast radius (repo-only now,
  firmware in one hardware-verified release); pinning one root CA on the download is worse than
  setInsecure. Adopted as ISC-101..105 and as the fix-batching rule.
- 2026-09-23 00:40: Production-readiness audit opened as ISC-56..96 on this project ISA. The
  criteria ARE the definition of production ready; the audit marks each one pass or fail with
  evidence. Fixes are a separate decision for Ian, because a release is an OTA push to every unit.
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

## Verification — production audit 2026-09-23

Full evidence: PAI/MEMORY/WORK/20260923-mini7seg-production-audit/{direct-probes,fleet-tally,report}.md
- ISC-56: Bash — `pio run` SUCCESS, 0 warnings at default flags, RAM 15.3% (50284 B), flash 70.8% (1391270 B); -Wall adds four %u/uint32_t format warnings
- ISC-65: curl — `/checkupdate` -> {"ok":true,"current":"1.1.0","latest":"1.0.0","newer":false}
- ISC-82: Interceptor — real Chrome, html constrained to 400 px: settings worstRight=400 fits=true; wiring svgW=365, 28 polygons, 4 circles, fits=true
- ISC-99: Bash — `diff -rq 7segclock/src mini7seg/firmware/ntp4digit/src` IDENTICAL (hand-synced; passes today only)
- ISC-100: Read — isNewer() strict greater-than; live device newer:false against 1.0.0
- ISC-102: Grep — framework-arduinoespressif32-libs/esp32c3/sdkconfig:328 CONFIG_BOOTLOADER_APP_ROLLBACK_ENABLE=y, :3392 CONFIG_APP_ROLLBACK_ENABLE=y; cores/esp32/esp32-hal-misc.c:285 weak verifyRollbackLater(); release factory image carries the bootloader string "rollback to the previous version"
- ISC-104: Grep — no `millis() >` or `last + interval` forms in src/; all interval checks subtract
- ISC-106 (FAIL): Bash — `rg -a -c` on docs/firmware.factory.bin: checkupdate 0, doupdate 0, api.github.com 0, setgeometry 0, "fw" 0, wiring 0; release firmware.bin: checkupdate 2
- ISC-107 (FAIL): Read — main.cpp:874-884 has no isNewer() gate and fetches releases/latest
- ISC-109 (FAIL): Bash — `git rev-list -n1 v1.0.0` = c3e5461; `git show v1.0.0:src/main.cpp` has no FW_VERSION
- ISC-110 (FAIL): Read — geometryJson() has no ok field; geometryui.h:131 tests j.ok
- ISC-57 (FAIL): Bash — `pio pkg list`: Platform espressif32 @ 55.3.38 satisfied the unpinned spec; FastLED ^3.10.0 -> 3.10.5; library -> git HEAD 6c695db
- ISC-58 (FAIL): fleet `pio ci` — mixed_strip: RGB is not a class; the other five: DATA_PIN 13 rejected by FastLED on esp32-c3-devkitm-1
- ISC-97 (FAIL): see ISC-106; manifest.json version 1.0.0; release firmware.bin contains "1.0.0"
- ISC-59: gh — Actions run 35879434124 on 60d00dd: all 8 steps success in 5m10s; contract step printed the firmware.bin OK line (CI evidence below)
- All other ISC-56..120: FAIL by inspection — evidence in fleet-tally.md (107 confirmed findings, 3 refuted) and the Forge report F1-F26

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
