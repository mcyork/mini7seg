// Must compile: the positive control for the two reject_* files, so a failing
// compile there is proven to come from the pixel-type checks and not from some
// unrelated error (a missing include, a typo).
#include "String7Segment.h"

struct RGB  { uint8_t r, g, b; };
struct RGBW { uint8_t r, g, b, w; };
RGB  rgb[8];
RGBW rgbw[8];
String7Segment a(rgb, 0);
String7Segment b(rgbw, 0, 1, 1);

int main() { a.showDigit(8); b.showDigit(8); return 0; }
