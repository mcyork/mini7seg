/*
 * String7Segment - Implementation
 */

#include "String7Segment.h"

// Segment patterns for displayable characters
// Bit order: DP G F E D C B A
const uint8_t SEGMENT_PATTERNS[] = {
  // 0-9
  0b00111111,  // 0: A B C D E F
  0b00000110,  // 1: B C
  0b01011011,  // 2: A B D E G
  0b01001111,  // 3: A B C D G
  0b01100110,  // 4: B C F G
  0b01101101,  // 5: A C D F G
  0b01111101,  // 6: A C D E F G
  0b00000111,  // 7: A B C
  0b01111111,  // 8: A B C D E F G
  0b01101111,  // 9: A B C D F G

  // A-F (hex)
  0b01110111,  // A: A B C E F G
  0b01111100,  // b: C D E F G (lowercase looks better)
  0b00111001,  // C: A D E F
  0b01011110,  // d: B C D E G (lowercase looks better)
  0b01111001,  // E: A D E F G
  0b01110001,  // F: A E F G

  // Extended characters (index 16+)
  0b01110110,  // H: B C E F G (index 16)
  0b00011110,  // J: B C D E (index 17)
  0b00111000,  // L: D E F (index 18)
  0b01010100,  // n: C E G (lowercase) (index 19)
  0b01011100,  // o: C D E G (lowercase) (index 20)
  0b01110011,  // P: A B E F G (index 21)
  0b01010000,  // r: E G (lowercase) (index 22)
  0b00111110,  // U: B C D E F (index 23)
  0b01101110,  // Y: B C D F G (index 24)
  0b01000000,  // - (minus): G (index 25)
  0b00001000,  // _ (underscore): D (index 26)
  0b00000000,  // (space): nothing (index 27)
};

// Get pattern for a character
uint8_t String7Segment::getPattern(char c) {
  if (c >= '0' && c <= '9') {
    return SEGMENT_PATTERNS[c - '0'];
  }
  if (c >= 'A' && c <= 'F') {
    return SEGMENT_PATTERNS[10 + (c - 'A')];
  }
  if (c >= 'a' && c <= 'f') {
    return SEGMENT_PATTERNS[10 + (c - 'a')];
  }

  // Extended characters
  switch (c) {
    case 'H': case 'h': return SEGMENT_PATTERNS[16];
    case 'J': case 'j': return SEGMENT_PATTERNS[17];
    case 'L': case 'l': return SEGMENT_PATTERNS[18];
    case 'N': case 'n': return SEGMENT_PATTERNS[19];
    case 'O': case 'o': return SEGMENT_PATTERNS[20];
    case 'P': case 'p': return SEGMENT_PATTERNS[21];
    case 'R': case 'r': return SEGMENT_PATTERNS[22];
    case 'U': case 'u': return SEGMENT_PATTERNS[23];
    case 'Y': case 'y': return SEGMENT_PATTERNS[24];
    case '-':           return SEGMENT_PATTERNS[25];
    case '_':           return SEGMENT_PATTERNS[26];
    case ' ':           return SEGMENT_PATTERNS[27];
    default:            return 0;  // Unknown = blank
  }
}

// A space is displayable (deliberately blank); anything else that maps to 0 is not.
bool String7Segment::isDisplayable(char c) {
  return c == ' ' || getPattern(c) != 0;
}

// Write color to a specific LED in the array. The first three bytes of a pixel are
// R, G, B (FastLED's CRGB layout); a fourth (white) byte is cleared so a pixel that
// was lit white by other code does not stay lit.
void String7Segment::setPixel(uint32_t index, S7Color color) {
  uint8_t* pixel = _ledPtr + index * _pixelSize;
  pixel[0] = color.r;
  pixel[1] = color.g;
  pixel[2] = color.b;
  if (_pixelSize >= 4) pixel[3] = 0;
}

// Read color from a specific LED in the array
S7Color String7Segment::getPixel(uint32_t index) {
  uint8_t* pixel = _ledPtr + index * _pixelSize;
  return S7Color(pixel[0], pixel[1], pixel[2]);
}

void String7Segment::paintLit(uint32_t index) {
  if (_bgMode == BG_BLEND) {
    S7Color was = getPixel(index);
    uint8_t* pixel = _ledPtr + index * _pixelSize;
    uint8_t w = (_pixelSize >= 4) ? pixel[3] : 0;
    setPixel(index, S7Color((uint8_t)(((uint16_t)was.r + _foreground.r) / 2),
                            (uint8_t)(((uint16_t)was.g + _foreground.g) / 2),
                            (uint8_t)(((uint16_t)was.b + _foreground.b) / 2)));
    if (_pixelSize >= 4) pixel[3] = w / 2;   // the foreground has no white, so blend W toward 0
  } else {
    setPixel(index, _foreground);
  }
}

void String7Segment::paintUnlit(uint32_t index) {
  if (_bgMode == BG_OVERWRITE) setPixel(index, _background);
  // BG_PRESERVE and BG_BLEND leave unlit pixels exactly as they are.
}

// Erasing is not the same as "not lit": clear() and DP-off exist to take the
// display's own marks away, so they write the background in BLEND too (as 1.0.0
// did). Only BG_PRESERVE means "never touch a pixel I am not lighting".
void String7Segment::paintCleared(uint32_t index) {
  if (_bgMode != BG_PRESERVE) setPixel(index, _background);
}

// Display a single digit (0-9)
void String7Segment::showDigit(uint8_t digit, uint8_t position, bool showDP) {
  if (digit > 9) digit = 9;
  uint8_t pattern = SEGMENT_PATTERNS[digit];
  if (showDP) pattern |= SEG_DP;
  showSegments(pattern, position);
}

// Display a character
void String7Segment::showChar(char c, uint8_t position, bool showDP) {
  uint8_t pattern = getPattern(c);
  if (showDP) pattern |= SEG_DP;
  showSegments(pattern, position);
}

// Display raw segment pattern
void String7Segment::showSegments(uint8_t segmentMask, uint8_t position) {
  if (position >= _numDigits) return;

  uint32_t baseIndex = digitBase(position);

  for (uint8_t seg = 0; seg < 8; seg++) {
    bool segmentOn = (segmentMask >> seg) & 0x01;
    for (uint8_t led = 0; led < _ledsPerSegment; led++) {
      uint32_t ledIndex = baseIndex + (uint32_t)seg * _ledsPerSegment + led;
      if (segmentOn) paintLit(ledIndex);
      else           paintUnlit(ledIndex);
    }
  }
}

void String7Segment::showDashes() {
  for (uint8_t pos = 0; pos < _numDigits; pos++) showChar('-', pos);
}

// Display a number across the digits, right-aligned
bool String7Segment::showNumber(int32_t number, bool leadingZeros) {
  bool negative = number < 0;
  // Magnitude as unsigned: -INT32_MIN does not fit in int32_t, 0u - (uint32_t)x does.
  uint32_t mag = negative ? 0u - (uint32_t)number : (uint32_t)number;

  // Extract digits right-to-left
  uint8_t digits[10];
  uint8_t digitCount = 0;
  do {
    digits[digitCount++] = mag % 10;
    mag /= 10;
  } while (mag > 0 && digitCount < 10);

  // The sign needs a digit of its own. If it does not fit, say so on the
  // display rather than showing a number that is not the number.
  if (digitCount + (negative ? 1 : 0) > _numDigits) {
    showDashes();
    return false;
  }

  for (uint8_t pos = 0; pos < _numDigits; pos++) {
    uint8_t displayPos = _numDigits - 1 - pos;  // rightmost first
    if (pos < digitCount) {
      showDigit(digits[pos], displayPos);
    } else if (negative && (leadingZeros ? displayPos == 0 : pos == digitCount)) {
      showChar('-', displayPos);                  // leftmost with zeros, else just before the digits
    } else if (leadingZeros) {
      showDigit(0, displayPos);
    } else {
      clearDigit(displayPos);
    }
  }
  return true;
}

// Display hexadecimal value
void String7Segment::showHex(uint32_t value, uint8_t digits) {
  if (digits == 0) digits = _numDigits;
  if (digits > _numDigits) digits = _numDigits;

  for (uint8_t pos = 0; pos < digits; pos++) {
    uint8_t displayPos = _numDigits - 1 - pos;
    uint8_t nibble = (pos < 8) ? (value >> (pos * 4)) & 0x0F : 0;

    if (nibble < 10) {
      showDigit(nibble, displayPos);
    } else {
      showChar('A' + (nibble - 10), displayPos);
    }
  }

  // Clear remaining positions
  for (uint8_t pos = digits; pos < _numDigits; pos++) {
    clearDigit(_numDigits - 1 - pos);
  }
}

// Clear all digits
void String7Segment::clear() {
  for (uint8_t pos = 0; pos < _numDigits; pos++) {
    clearDigit(pos);
  }
}

// Clear a single digit: background colour in OVERWRITE and BLEND, untouched in PRESERVE.
void String7Segment::clearDigit(uint8_t position) {
  if (position >= _numDigits) return;
  uint32_t base = digitBase(position);
  for (uint32_t i = 0; i < getLedsPerDigit(); i++) paintCleared(base + i);
}

// Set decimal point on/off
void String7Segment::setDecimalPoint(uint8_t position, bool on) {
  if (position >= _numDigits) return;

  // DP is segment 7 (index 7 * ledsPerSegment)
  uint32_t dpBase = digitBase(position) + (uint32_t)7 * _ledsPerSegment;
  for (uint8_t led = 0; led < _ledsPerSegment; led++) {
    if (on) paintLit(dpBase + led);
    else    paintCleared(dpBase + led);
  }
}

// Spin animation - outer ring segments in clockwise order: A B C D E F
// Step 0=A, 1=B, 2=C, 3=D, 4=E, 5=F
static const uint8_t SPIN_SEGMENTS[] = {
  SEG_A,  // step 0 - top
  SEG_B,  // step 1 - upper right
  SEG_C,  // step 2 - lower right
  SEG_D,  // step 3 - bottom
  SEG_E,  // step 4 - lower left
  SEG_F   // step 5 - upper left
};

uint8_t String7Segment::getSpinSegment(uint8_t step) {
  return SPIN_SEGMENTS[step % 6];
}

void String7Segment::spinStep(uint8_t step, uint8_t position) {
  showSegments(SPIN_SEGMENTS[step % 6], position);
}
