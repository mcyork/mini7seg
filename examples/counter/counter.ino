/*
 * Counter Demo - Simple 0-9 counting display
 * Good for demo videos and testing hardware.
 */

#include <FastLED.h>
#include "String7Segment.h"

#define DATA_PIN    4     // any pin your board can drive; 4 exists on ESP32, C3, S3 and AVR
#define NUM_LEDS    8
#define BRIGHTNESS  128

CRGB leds[NUM_LEDS];
String7Segment display(leds, 0);

void setup() {
  FastLED.addLeds<WS2812, DATA_PIN, GRB>(leds, NUM_LEDS);
  FastLED.setBrightness(BRIGHTNESS);
  FastLED.setCorrection(TypicalSMD5050);

  display.setForeground(S7Color::Red());
  display.setBackground(S7Color::Black());
  display.setBackgroundMode(BG_OVERWRITE);
}

void loop() {
  for (int i = 0; i <= 9; i++) {
    display.showDigit(i);
    FastLED.show();
    delay(500);
  }
}
