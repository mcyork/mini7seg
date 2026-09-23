/*
 * String7Segment - Addressable LED 7-Segment Display Library
 *
 * Drive 7-segment displays made from WS2812/NeoPixel LEDs.
 * Designed to work alongside existing LED arrays - we modify
 * only our segments and let you call show() when ready.
 *
 * Hardware: 8 LEDs per digit in segment order A,B,C,D,E,F,G,DP
 * (or ledsPerSegment LEDs per segment, all of A first, then B, ...)
 *
 * PIXEL TYPES
 *   The LED array must be an array of a 3- or 4-byte STRUCT whose first three
 *   bytes are red, green, blue in that order — FastLED's CRGB, or your own
 *   RGB/RGBW struct. For a 4-byte pixel the fourth (white) byte is cleared when
 *   a colour is written. Rejected at compile time: byte buffers (for example
 *   Adafruit_NeoPixel::getPixels(), packed GRB) and plain integers (uint32_t
 *   colours from strip.Color()). NOT detectable and NOT supported: structs of
 *   the right size in another order, such as FastLED's CHSV — they compile and
 *   show the wrong colours.
 *
 * BOUNDS
 *   The library never checks the array's length. It writes exactly the
 *   getLedCount() pixels starting at `offset`; your array must hold
 *   offset + getLedCount() pixels. ledsPerSegment is 1..255.
 *
 * License: MIT
 */

#ifndef STRING_7_SEGMENT_H
#define STRING_7_SEGMENT_H

#include <stdint.h>

// Segment bit positions (matches physical LED order)
#define SEG_A   0x01  // bit 0
#define SEG_B   0x02  // bit 1
#define SEG_C   0x04  // bit 2
#define SEG_D   0x08  // bit 3
#define SEG_E   0x10  // bit 4
#define SEG_F   0x20  // bit 5
#define SEG_G   0x40  // bit 6
#define SEG_DP  0x80  // bit 7

// Background modes — what happens to the pixels of segments that are NOT lit,
// and how lit segments combine with what is already in the array.
//
//                 lit segment              unlit segment (show*)   clear()/clearDigit()/DP off
//   BG_OVERWRITE  foreground               background colour       background colour
//   BG_PRESERVE   foreground               untouched               untouched
//   BG_BLEND      50/50 foreground + what  untouched               background colour
//                 is in the array NOW
//
// BG_BLEND mixes with whatever the array holds at the moment of the call, so
// repaint your underlying layer before each show*() — calling it again on the
// same pixels moves them halfway closer to the foreground each time.
enum BackgroundMode {
  BG_OVERWRITE,
  BG_PRESERVE,
  BG_BLEND
};

// Simple colour struct. Named S7Color rather than CRGB so it never collides with
// FastLED's CRGB when both headers are included.
struct S7Color {
  uint8_t r, g, b;

  S7Color() : r(0), g(0), b(0) {}
  S7Color(uint8_t red, uint8_t green, uint8_t blue) : r(red), g(green), b(blue) {}

  // Common colors
  static S7Color Black()   { return S7Color(0, 0, 0); }
  static S7Color White()   { return S7Color(255, 255, 255); }
  static S7Color Red()     { return S7Color(255, 0, 0); }
  static S7Color Green()   { return S7Color(0, 255, 0); }
  static S7Color Blue()    { return S7Color(0, 0, 255); }
  static S7Color Yellow()  { return S7Color(255, 255, 0); }
  static S7Color Cyan()    { return S7Color(0, 255, 255); }
  static S7Color Magenta() { return S7Color(255, 0, 255); }
  static S7Color Orange()  { return S7Color(255, 128, 0); }
};

// Segment patterns for characters
// Index 0-9 = digits, 10-15 = A-F, 16+ = special chars
extern const uint8_t SEGMENT_PATTERNS[];

class String7Segment {
public:
  // Constructor for single digit
  // ledArray: pointer to your LED array (CRGB* or any 3/4-byte RGB(W) struct)
  // offset: where our LEDs start in the array
  template<typename T>
  String7Segment(T* ledArray, uint16_t offset)
    : _ledPtr((uint8_t*)ledArray)
    , _offset(offset)
    , _numDigits(1)
    , _ledsPerSegment(1)
    , _pixelSize(sizeof(T))
    , _foreground(S7Color::Red())
    , _background(S7Color::Black())
    , _bgMode(BG_OVERWRITE)
  { checkPixelType<T>(); }

  // Constructor for multiple digits
  template<typename T>
  String7Segment(T* ledArray, uint16_t offset, uint8_t numDigits)
    : _ledPtr((uint8_t*)ledArray)
    , _offset(offset)
    , _numDigits(numDigits)
    , _ledsPerSegment(1)
    , _pixelSize(sizeof(T))
    , _foreground(S7Color::Red())
    , _background(S7Color::Black())
    , _bgMode(BG_OVERWRITE)
  { checkPixelType<T>(); }

  // Constructor with custom LEDs per segment (for larger displays)
  template<typename T>
  String7Segment(T* ledArray, uint16_t offset, uint8_t numDigits, uint8_t ledsPerSegment)
    : _ledPtr((uint8_t*)ledArray)
    , _offset(offset)
    , _numDigits(numDigits)
    , _ledsPerSegment(ledsPerSegment)
    , _pixelSize(sizeof(T))
    , _foreground(S7Color::Red())
    , _background(S7Color::Black())
    , _bgMode(BG_OVERWRITE)
  { checkPixelType<T>(); }

  // Color settings
  void setForeground(S7Color color) { _foreground = color; }
  void setForeground(uint8_t r, uint8_t g, uint8_t b) { _foreground = S7Color(r, g, b); }
  void setBackground(S7Color color) { _background = color; }
  void setBackground(uint8_t r, uint8_t g, uint8_t b) { _background = S7Color(r, g, b); }
  void setBackgroundMode(BackgroundMode mode) { _bgMode = mode; }

  // Display functions
  void showDigit(uint8_t digit, uint8_t position = 0, bool showDP = false);   // digit > 9 shows 9
  void showChar(char c, uint8_t position = 0, bool showDP = false);           // unknown chars show blank
  void showSegments(uint8_t segmentMask, uint8_t position = 0);
  // Right-aligned. Negative numbers get a leading '-'; with leadingZeros the '-'
  // takes the leftmost digit and zeros fill between. If the number (with its
  // sign) does not fit, every digit shows '-' and the call returns false.
  bool showNumber(int32_t number, bool leadingZeros = false);
  void showHex(uint32_t value, uint8_t digits = 0);

  // Utility. Position 0 is the LEFTMOST digit and the first on the data line.
  // clear()/clearDigit() and setDecimalPoint(off) write the background colour in
  // BG_OVERWRITE and BG_BLEND, and leave the pixels alone in BG_PRESERVE.
  void clear();
  void clearDigit(uint8_t position = 0);
  void setDecimalPoint(uint8_t position, bool on = true);

  // Animations
  void spinStep(uint8_t step, uint8_t position = 0);  // step 0-5 for outer ring
  uint8_t getSpinSegment(uint8_t step);               // Get segment mask for spin step

  // Get segment pattern for a character (0 for unknown characters AND for ' ')
  static uint8_t getPattern(char c);
  // True if the character has a pattern (including ' ', which is deliberately blank)
  static bool isDisplayable(char c);

  // Configuration
  void setLedsPerSegment(uint8_t count) { _ledsPerSegment = count; }
  uint8_t getLedsPerSegment() const { return _ledsPerSegment; }
  uint16_t getLedsPerDigit() const { return (uint16_t)8 * _ledsPerSegment; }
  // Pixels this display writes, starting at its offset. Size your array to at
  // least offset + getLedCount(). 32-bit: 255 digits x 8 x 255 LEDs does not fit 16.
  uint32_t getLedCount() const { return (uint32_t)_numDigits * getLedsPerDigit(); }

private:
  // "Is T a class/struct?" without <type_traits>, which AVR toolchains lack: only
  // a class type can form a pointer-to-member. Rejects uint32_t, float, etc.
  template<typename U> static char classProbe(int U::*);
  template<typename U> static long classProbe(...);

  template<typename T>
  static void checkPixelType() {
    static_assert(sizeof(T) == 3 || sizeof(T) == 4,
                  "String7Segment needs an array of 3-byte RGB or 4-byte RGBW pixels "
                  "(e.g. FastLED's CRGB). A byte buffer such as Adafruit_NeoPixel::getPixels() "
                  "is packed GRB and is not supported.");
    static_assert(sizeof(classProbe<T>(0)) == 1,
                  "String7Segment needs an array of pixel STRUCTS (e.g. FastLED's CRGB), not "
                  "integers: a uint32_t colour from Adafruit_NeoPixel::Color() is 0x00RRGGBB "
                  "and would be written with red and blue swapped.");
  }

  uint8_t* _ledPtr;         // Pointer to LED array (as bytes)
  uint16_t _offset;         // Starting index in LED array
  uint8_t  _numDigits;      // Number of digits
  uint8_t  _ledsPerSegment; // LEDs per segment (1, 2, or 3 typical)
  uint8_t  _pixelSize;      // Size of each pixel struct (3 for RGB, 4 for RGBW)
  S7Color  _foreground;     // Lit segment color
  S7Color  _background;     // Unlit segment color
  BackgroundMode _bgMode;   // How to handle unlit segments

  // Pixel indices are 32-bit: offset + getLedCount() can exceed 65535.
  void setPixel(uint32_t index, S7Color color);
  S7Color getPixel(uint32_t index);
  void paintLit(uint32_t index);     // foreground, or a blend with what is there
  void paintUnlit(uint32_t index);   // background, or nothing (show* in PRESERVE/BLEND)
  void paintCleared(uint32_t index); // background, or nothing (clear/DP-off in PRESERVE)
  uint32_t digitBase(uint8_t position) const {
    return (uint32_t)_offset + (uint32_t)position * getLedsPerDigit();
  }
  void showDashes();
};

#endif // STRING_7_SEGMENT_H
