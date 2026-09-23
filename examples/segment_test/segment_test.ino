/*
 * Segment Test - Identify which LED is which segment
 *
 * Lights up each segment one at a time, cycling through:
 * A (top), B (upper right), C (lower right), D (bottom),
 * E (lower left), F (upper left), G (middle), DP (decimal point)
 *
 * Watch which LED lights and note its position.
 */

#include <FastLED.h>

#define DATA_PIN    4     // any pin your board can drive; 4 exists on ESP32, C3, S3 and AVR
#define NUM_LEDS    8
#define BRIGHTNESS  50

CRGB leds[NUM_LEDS];

// Segment names for reference
const char* segmentNames[] = {
  "A (top)",
  "B (upper right)",
  "C (lower right)",
  "D (bottom)",
  "E (lower left)",
  "F (upper left)",
  "G (middle)",
  "DP (decimal point)"
};

void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("\n\nSegment Test - Watch which LED lights up");
  Serial.println("Standard 7-segment layout:");
  Serial.println("   AAA");
  Serial.println("  F   B");
  Serial.println("   GGG");
  Serial.println("  E   C");
  Serial.println("   DDD  DP");
  Serial.println("");

  FastLED.addLeds<WS2812, DATA_PIN, GRB>(leds, NUM_LEDS);
  FastLED.setBrightness(BRIGHTNESS);
}

void loop() {
  // Light each segment one at a time
  for (int i = 0; i < 8; i++) {
    // Clear all
    fill_solid(leds, NUM_LEDS, CRGB::Black);

    // Light just this segment
    leds[i] = CRGB::Red;
    FastLED.show();

    Serial.print("LED ");
    Serial.print(i);
    Serial.print(" = ");
    Serial.println(segmentNames[i]);

    delay(1500);
  }

  Serial.println("\n--- Restarting cycle ---\n");
  delay(1000);
}
