# Building

This repo builds the **library examples** (Arduino IDE or arduino-cli). The
**clock firmware** lives in [mcyork/7segclock](https://github.com/mcyork/7segclock);
see that README for flashing a clock, and its `dev` PlatformIO environment for
building the firmware against a local checkout of this library.

## Library examples — Arduino IDE

1. Install the library: **Sketch → Include Library → Add .ZIP Library**, or clone
   this repo into `~/Documents/Arduino/libraries/`.
2. Install **FastLED** from the Library Manager (the examples use it; the library
   itself has no dependencies).
3. Open any sketch under `examples/`, set `DATA_PIN` to a pin your board can
   drive, and upload.

## Library examples — arduino-cli

```bash
arduino-cli core update-index --additional-urls https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json
arduino-cli core install esp32:esp32
arduino-cli lib install FastLED

# Any ESP32 works; the pin in each example must exist on your board.
arduino-cli compile --fqbn esp32:esp32:esp32s3 --library . examples/basic/basic.ino
```

On Apple Silicon without Rosetta, arduino-cli 1.5.x fails in the preprocessor
(its bundled ctags is x86-only). Use PlatformIO there:

```bash
pio ci --board esp32-s3-devkitc-1 --lib . -l FastLED examples/basic/basic.ino
```

## Clock firmware against this checkout

```bash
git clone https://github.com/mcyork/7segclock ../7segclock   # side by side with this repo
cd ../7segclock
pio run -e dev          # library from ../mini7seg via symlink, everything else pinned
pio run -e dev -t upload
```

Releases are always built from the pinned `c3supermini` environment, never from `dev`.

## Notes

- Target board for the clock is the **ESP32-C3 Super Mini**. Its data pin
  allow-list lives in 7segclock's `src/settings.h` (`PIN_XLIST`);
  strapping pins are deliberately withheld.
- USB CDC on boot is required on the C3 (`ARDUINO_USB_CDC_ON_BOOT=1`) or there is
  no serial port at all.
