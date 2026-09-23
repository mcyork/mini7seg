/*
 * Spin Animation Example
 *
 * Demonstrates spinning animations using the outer ring
 * of segments (A, B, C, D, E, F) - excludes G (middle) and DP
 */

#include <FastLED.h>
#include "String7Segment.h"

#define DATA_PIN    4     // any pin your board can drive; 4 exists on ESP32, C3, S3 and AVR
#define NUM_LEDS    8
#define BRIGHTNESS  50

CRGB leds[NUM_LEDS];
String7Segment display(leds, 0);

void setup() {
  Serial.begin(115200);
  Serial.println("Spin Animation Demo");

  FastLED.addLeds<WS2812, DATA_PIN, GRB>(leds, NUM_LEDS);
  FastLED.setBrightness(BRIGHTNESS);

  display.setForeground(S7Color::Green());
  display.setBackground(S7Color::Black());
  display.setBackgroundMode(BG_OVERWRITE);
}

void loop() {
  // Clockwise spin (A → B → C → D → E → F)
  display.setForeground(S7Color::Green());
  for (int cycles = 0; cycles < 3; cycles++) {
    for (int step = 0; step < 6; step++) {
      display.spinStep(step);
      FastLED.show();
      delay(100);
    }
  }

  delay(300);

  // Counter-clockwise spin (F → E → D → C → B → A)
  display.setForeground(S7Color::Blue());
  for (int cycles = 0; cycles < 3; cycles++) {
    for (int step = 5; step >= 0; step--) {
      display.spinStep(step);
      FastLED.show();
      delay(100);
    }
  }

  delay(300);

  // Fast spin with trail (2 segments lit)
  display.setForeground(S7Color::Red());
  for (int cycles = 0; cycles < 4; cycles++) {
    for (int step = 0; step < 6; step++) {
      // Light current and previous segment for trail effect
      uint8_t pattern = display.getSpinSegment(step) |
                        display.getSpinSegment((step + 5) % 6);
      display.showSegments(pattern);
      FastLED.show();
      delay(60);
    }
  }

  delay(300);

  // Alternating halves (top vs bottom)
  display.setForeground(S7Color::Yellow());
  for (int cycles = 0; cycles < 4; cycles++) {
    // Top half: A F B
    display.showSegments(SEG_A | SEG_F | SEG_B);
    FastLED.show();
    delay(200);

    // Bottom half: D E C
    display.showSegments(SEG_D | SEG_E | SEG_C);
    FastLED.show();
    delay(200);
  }

  delay(300);

  // Growing/shrinking ring
  display.setForeground(S7Color::Cyan());
  for (int cycles = 0; cycles < 2; cycles++) {
    // Build up
    uint8_t pattern = 0;
    for (int step = 0; step < 6; step++) {
      pattern |= display.getSpinSegment(step);
      display.showSegments(pattern);
      FastLED.show();
      delay(100);
    }
    delay(200);

    // Tear down
    for (int step = 0; step < 6; step++) {
      pattern &= ~display.getSpinSegment(step);
      display.showSegments(pattern);
      FastLED.show();
      delay(100);
    }
    delay(200);
  }

  // Clear and pause before repeat
  display.clear();
  FastLED.show();
  delay(1000);
}
