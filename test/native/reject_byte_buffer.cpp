// Must NOT compile: a byte buffer (Adafruit_NeoPixel::getPixels() returns uint8_t*,
// packed GRB) would be written as if every byte were a pixel. The constructor's
// static_assert rejects it. CI compiles this and requires the compile to fail.
#include "String7Segment.h"

uint8_t bytes[24];
String7Segment display(bytes, 0);

int main() { return 0; }
