# String7Segment Library Design

> **Historical design note (early 2026).** This is the original sketch the
> library grew from. The API names, example list and target board below no
> longer match the code — `README.md` is the reference for what the library
> does today, and `hardware/README.md` for the boards and enclosure. Kept for
> the reasoning, not the details.

## Overview

A library for driving 7-segment displays made from addressable LEDs (WS2812/NeoPixel) that plays nicely with existing LED arrays managed by FastLED or Adafruit NeoPixel.

## Hardware

- 8x WS2812 2020 LEDs per digit
- Wired in segment order: A, B, C, D, E, F, G, DP (indices 0-7)
- Single data wire, directly addressable

```
    AAAA
   F    B
   F    B
    GGGG
   E    C
   E    C
    DDDD  DP
```

## Key Design Principle

**We don't own the LED array.** Users may have a strip of 300 LEDs with our 7-segment display somewhere in the middle. We:

1. Accept a pointer to their CRGB array (or compatible)
2. Accept an offset (where our 8 LEDs start)
3. Modify only our 8 LEDs
4. Hand it back - they call FastLED.show() when ready

## API Sketch

```cpp
#include <String7Segment.h>

// User's LED array (managed by FastLED)
CRGB leds[300];
FastLED.addLeds<WS2812, DATA_PIN, GRB>(leds, 300);

// Our display starts at index 50 in their array
String7Segment display(leds, 50);  // pointer + offset

// Or multiple digits
String7Segment display(leds, 50, 4);  // 4 digits starting at index 50

// Set colors
display.setForeground(CRGB::Red);
display.setBackground(CRGB::Black);  // or CRGB_TRANSPARENT to preserve

// Display something
display.showDigit(7);           // Single digit
display.showNumber(1234);       // Multi-digit
display.showChar('A');          // Hex/letters
display.showSegments(0b01101101); // Raw segment mask

// Background modes
display.setBackgroundMode(BG_OVERWRITE);  // Set unlit segments to background color
display.setBackgroundMode(BG_PRESERVE);   // Don't touch unlit segments
display.setBackgroundMode(BG_BLEND);      // Blend with existing (for effects)

// User calls show when ready
FastLED.show();
```

## Segment Encoding

Standard 7-segment bit mapping:

```
Bit:  7  6  5  4  3  2  1  0
Seg:  DP G  F  E  D  C  B  A

0 = 0b00111111 (A,B,C,D,E,F)
1 = 0b00000110 (B,C)
2 = 0b01011011 (A,B,D,E,G)
...
```

## Files

```
string_7_segment/
├── src/
│   ├── String7Segment.h      # Main header
│   └── String7Segment.cpp    # Implementation
├── examples/
│   ├── basic/
│   │   └── basic.ino         # Simple digit display
│   ├── counter/
│   │   └── counter.ino       # Counting demo
│   └── mixed_strip/
│       └── mixed_strip.ino   # 7-seg in middle of LED strip
├── DESIGN.md                  # This file
├── README.md                  # Public docs
└── library.json               # PlatformIO manifest
```

## Considerations

- **No FastLED dependency in header** - use forward declarations or templates so users can use Adafruit NeoPixel too
- **Color type agnostic** - work with any RGB struct that has r, g, b members
- **Multi-digit support** - chain displays, handle numbers wider than display
- **Animations** - maybe later (blink, fade, scroll)

## Target Platform

Primary: ESP32 (ESP32-S3 specifically)
Secondary: Should compile on Arduino AVR, but not actively testing

## Phase 1 Goals

1. Single digit display working
2. Basic character set (0-9, A-F, some letters)
3. Background modes (overwrite, preserve)
4. Demo sketch running on ESP32
