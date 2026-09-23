// Must NOT compile: an array of uint32_t colours (Adafruit_NeoPixel::Color() packs
// 0x00RRGGBB) is 4 bytes like an RGBW struct, but would be written with red and
// blue swapped. The pointer-to-member probe in checkPixelType() rejects non-structs.
#include "String7Segment.h"

uint32_t colours[8];
String7Segment display(colours, 0);

int main() { return 0; }
