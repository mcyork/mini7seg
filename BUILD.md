# Building

Two things build from this repo: the **library examples** (Arduino IDE or
arduino-cli) and the **clock firmware** dev copy under `firmware/ntp4digit/`
(PlatformIO). The firmware's canonical home and release chain is
[mcyork/7segclock](https://github.com/mcyork/7segclock); see that README for
flashing a clock.

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

## Clock firmware — PlatformIO

```bash
cd firmware/ntp4digit
pio run                 # build against the library in this checkout
pio run -t upload       # flash over USB (ESP32-C3 Super Mini, native USB CDC)
pio device monitor      # 115200
```

Every dependency in `platformio.ini` is pinned to an exact version so a tagged
commit rebuilds the same firmware. Do not loosen the pins.

## Notes

- Target board for the clock is the **ESP32-C3 Super Mini**. Its data pin
  allow-list lives in `firmware/ntp4digit/src/settings.h` (`PIN_XLIST`);
  strapping pins are deliberately withheld.
- USB CDC on boot is required on the C3 (`ARDUINO_USB_CDC_ON_BOOT=1`) or there is
  no serial port at all.
