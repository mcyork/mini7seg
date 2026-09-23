// Host tests for String7Segment — the display logic, without a board or FastLED.
//
//   Build and run (one line; see .github/workflows/library.yml):
//   c++ -std=c++17 -Wall -Wextra -Werror -Isrc src/String7Segment.cpp test/native/test_string7segment.cpp -o s7test
//
// A pixel is a plain 3-byte RGB struct (the same layout as FastLED's CRGB); the
// RGBW cases use a 4-byte struct. Each check renders into an array and reads the
// segments back as characters, so a failure prints what the display would show.

#include "String7Segment.h"
#include <cstdio>
#include <cstring>
#include <string>

struct RGB  { uint8_t r, g, b; };
struct RGBW { uint8_t r, g, b, w; };

static int failures = 0, checks = 0;
#define CHECK(cond, ...) do { checks++; if (!(cond)) { failures++; std::printf("FAIL %s:%d  ", __FILE__, __LINE__); std::printf(__VA_ARGS__); std::printf("\n"); } } while (0)

// Read one digit back: a segment is "lit" if its first LED is the foreground colour.
static uint8_t maskAt(const RGB* leds, uint16_t offset, uint8_t pos, uint8_t lps, RGB fg) {
  uint8_t mask = 0;
  for (uint8_t seg = 0; seg < 8; seg++) {
    const RGB& p = leds[offset + pos * 8 * lps + seg * lps];
    if (p.r == fg.r && p.g == fg.g && p.b == fg.b) mask |= (1u << seg);
  }
  return mask;
}

// Turn a segment mask back into the character that produced it ('?' if none).
static char charOf(uint8_t mask) {
  mask &= 0x7F;
  if (mask == 0) return ' ';
  const char* alphabet = "0123456789AbCdEFHJLnoPrUY-_";
  for (const char* c = alphabet; *c; c++)
    if (String7Segment::getPattern(*c) == mask) return *c;
  return '?';
}

static std::string readBack(const RGB* leds, uint8_t digits, uint8_t lps = 1, uint16_t offset = 0) {
  RGB fg{255, 0, 0};
  std::string s;
  for (uint8_t d = 0; d < digits; d++) s += charOf(maskAt(leds, offset, d, lps, fg));
  return s;
}

static void number(int32_t n, bool zeros, const char* want, bool wantOk, uint8_t digits = 4) {
  RGB leds[64] = {};
  String7Segment disp(leds, 0, digits);
  bool ok = disp.showNumber(n, zeros);
  std::string got = readBack(leds, digits);
  CHECK(got == want && ok == wantOk, "showNumber(%ld, %s) on %u digits: got \"%s\" %s, want \"%s\" %s",
        (long)n, zeros ? "zeros" : "no-zeros", digits, got.c_str(), ok ? "true" : "false", want, wantOk ? "true" : "false");
}

int main() {
  // --- showNumber: the cases 1.0.0 got wrong, and the ones it got right -------
  number(1234,  false, "1234", true);
  number(42,    false, "  42", true);
  number(42,    true,  "0042", true);
  number(0,     false, "   0", true);
  number(-5,    false, "  -5", true);
  number(-5,    true,  "-005", true);        // 1.0.0 printed "0005"
  number(-123,  false, "-123", true);
  number(-1234, false, "----", false);       // 1.0.0 printed "1234", sign silently gone
  number(12345, false, "----", false);       // 1.0.0 printed "2345"
  number(INT32_MIN, false, "--------", false, 8);   // was undefined behaviour
  number(-9999999, false, "-9999999", true, 8);
  number(-7, true, "-7", true, 2);
  number(-7, false, "-", false, 1);

  // --- background modes --------------------------------------------------------
  {
    RGB leds[8];
    for (auto& p : leds) p = RGB{0, 0, 200};           // someone else's blue
    String7Segment d(leds, 0);
    d.setForeground(S7Color(200, 0, 0));
    d.setBackgroundMode(BG_BLEND);
    d.showDigit(1);                                    // segments B, C
    CHECK(leds[1].r == 100 && leds[1].b == 100, "BG_BLEND lit segment is a 50/50 mix: got %u,%u,%u", leds[1].r, leds[1].g, leds[1].b);
    CHECK(leds[0].b == 200 && leds[0].r == 0, "BG_BLEND leaves unlit segments alone: got %u,%u,%u", leds[0].r, leds[0].g, leds[0].b);
    d.setDecimalPoint(0, false);
    CHECK(leds[7].r == 0 && leds[7].b == 0, "BG_BLEND setDecimalPoint(off) erases to the background, as 1.0.0 did");
    d.clear();
    CHECK(leds[0].b == 0 && leds[1].r == 0, "BG_BLEND clear() erases to the background, as 1.0.0 did (review finding)");
    // A 1.0.0 BLEND sketch: clear(); showNumber(n); per frame. Old segments must not survive.
    String7Segment two(leds, 0);
    two.setForeground(S7Color(200, 0, 0));
    two.setBackgroundMode(BG_BLEND);
    two.showDigit(8); two.clear(); two.showDigit(1);
    CHECK(leds[0].r == 0, "BG_BLEND: segment A of a previous 8 is gone after clear() + showDigit(1)");
  }
  {
    RGBW leds[8];
    for (auto& p : leds) p = RGBW{0, 0, 0, 200};
    String7Segment d(leds, 0);
    d.setForeground(S7Color(200, 0, 0));
    d.setBackgroundMode(BG_BLEND);
    d.showDigit(1);
    CHECK(leds[1].r == 100 && leds[1].w == 100, "BG_BLEND on RGBW mixes W toward 0 instead of zeroing it: got r%u w%u", leds[1].r, leds[1].w);
  }
  {
    RGB leds[8];
    for (auto& p : leds) p = RGB{0, 0, 200};
    String7Segment d(leds, 0);
    d.setForeground(S7Color(255, 0, 0));
    d.setBackgroundMode(BG_PRESERVE);
    d.showDigit(1);
    CHECK(leds[1].r == 255 && leds[1].b == 0 && leds[0].b == 200, "BG_PRESERVE: lit = foreground, unlit untouched");
    d.clear();
    CHECK(leds[1].r == 255, "BG_PRESERVE clear() touches nothing");
  }
  {
    RGB leds[8];
    for (auto& p : leds) p = RGB{0, 0, 200};
    String7Segment d(leds, 0);
    d.setBackground(S7Color(1, 2, 3));
    d.showDigit(1);
    CHECK(leds[0].r == 1 && leds[0].g == 2 && leds[0].b == 3, "BG_OVERWRITE paints unlit segments with the background");
    d.clear();
    CHECK(leds[1].r == 1, "BG_OVERWRITE clear() paints background");
  }

  // --- the library writes exactly its own pixels --------------------------------
  {
    RGB leds[3 + 2 * 8 * 3 + 3];
    for (auto& p : leds) p = RGB{9, 9, 9};
    String7Segment d(leds, 3, 2, 3);                   // offset 3, 2 digits, 3 LEDs/segment
    CHECK(d.getLedCount() == 48, "getLedCount 2 digits x 3 lps = 48, got %lu", (unsigned long)d.getLedCount());
    d.showNumber(88);
    d.setDecimalPoint(1, true);
    bool before = leds[0].r == 9 && leds[1].r == 9 && leds[2].r == 9;
    bool after  = leds[51].r == 9 && leds[52].r == 9 && leds[53].r == 9;
    CHECK(before && after, "pixels outside [offset, offset+getLedCount()) are untouched");
    CHECK(readBack(leds, 2, 3, 3) == "88", "multi-LED segments render: got \"%s\"", readBack(leds, 2, 3, 3).c_str());
  }

  // --- widths the 1.0.0 types could not hold -------------------------------------
  {
    RGB big[8 * 50];
    String7Segment d(big, 0, 1, 50);
    CHECK(d.getLedsPerDigit() == 400, "getLedsPerDigit at 50 LEDs/segment = 400 (1.0.0 wrapped to 144), got %u", d.getLedsPerDigit());
    String7Segment huge(big, 0, 255, 255);            // never drawn: just the count
    CHECK(huge.getLedCount() == 520200u, "getLedCount 255 x 8 x 255 = 520200 (fits 32 bits, not 16), got %lu", (unsigned long)huge.getLedCount());
    d.showDigit(8);
    CHECK(big[6 * 50 + 49].r == 255, "last LED of segment G is lit at 50 LEDs/segment");
  }

  // --- RGBW: the white byte is cleared ---------------------------------------------
  {
    RGBW leds[8];
    for (auto& p : leds) p = RGBW{0, 0, 0, 255};       // lit white by someone else
    String7Segment d(leds, 0);
    d.showDigit(1);
    CHECK(leds[1].w == 0 && leds[1].r == 255, "RGBW lit segment: W cleared, R set");
    CHECK(leds[0].w == 0, "RGBW unlit segment (overwrite): W cleared");
  }

  // --- characters ---------------------------------------------------------------------
  CHECK(String7Segment::isDisplayable(' '), "space is displayable");
  CHECK(String7Segment::isDisplayable('P') && String7Segment::isDisplayable('y'), "P and y are displayable");
  CHECK(!String7Segment::isDisplayable('t') && !String7Segment::isDisplayable('S'), "t and S are not displayable");
  {
    RGB leds[32] = {};
    String7Segment d(leds, 0, 4);
    d.showHex(0xBEEF);
    CHECK(readBack(leds, 4) == "bEEF", "showHex(0xBEEF): got \"%s\"", readBack(leds, 4).c_str());
  }

  std::printf("%d checks, %d failed\n", checks, failures);
  return failures ? 1 : 0;
}
