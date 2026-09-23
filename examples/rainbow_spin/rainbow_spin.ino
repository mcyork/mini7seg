/*
 * Rainbow Spin - Two independent animations
 *
 * The spin cycles around the outer ring at its own pace.
 * The color slowly shifts through the rainbow independently.
 */

#include <FastLED.h>
#include "String7Segment.h"

#define DATA_PIN    4     // any pin your board can drive; 4 exists on ESP32, C3, S3 and AVR
#define NUM_LEDS    8
#define BRIGHTNESS  128

CRGB leds[NUM_LEDS];
String7Segment display(leds, 0);

// Animation state (independent timers)
uint8_t spinStep = 0;
uint8_t hue = 0;

unsigned long lastSpinTime = 0;
unsigned long lastHueTime = 0;

#define SPIN_INTERVAL  80    // ms between spin steps (fast spin)
#define HUE_INTERVAL   30    // ms between hue steps (slow rainbow)

void setup() {
  FastLED.addLeds<WS2812, DATA_PIN, GRB>(leds, NUM_LEDS);
  FastLED.setBrightness(BRIGHTNESS);

  // Colour correction: scales green (and a little blue) down so white looks neutral
  // on 5050/2020 WS2812s. Use UncorrectedColor to turn it off.
  FastLED.setCorrection(TypicalSMD5050);

  display.setBackground(S7Color::Black());
  display.setBackgroundMode(BG_OVERWRITE);
}

void loop() {
  unsigned long now = millis();

  // Update hue independently (slow rainbow cycle)
  if (now - lastHueTime >= HUE_INTERVAL) {
    lastHueTime = now;
    hue++;  // wraps at 255

    // Convert HSV to RGB for the foreground color
    CHSV hsv(hue, 255, 255);
    CRGB rgb;
    hsv2rgb_rainbow(hsv, rgb);
    display.setForeground(rgb.r, rgb.g, rgb.b);
  }

  // Update spin independently (faster rotation)
  if (now - lastSpinTime >= SPIN_INTERVAL) {
    lastSpinTime = now;
    spinStep = (spinStep + 1) % 6;

    display.spinStep(spinStep);
    display.setDecimalPoint(0, true);  // Keep DP on to show color
    FastLED.show();
  }
}
