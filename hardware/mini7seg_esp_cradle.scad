// =============================================================================
// mini7seg_esp_cradle.scad
//
// How an ESP32-C3 Super Mini — which has NO mounting holes — is held in the
// back of the display enclosure, free-wired, with its USB-C reachable.
//
// THE LOAD PATH IS THE WHOLE DESIGN
//   The only rigid, structural thing on this board is the USB-C shell: it is
//   soldered down with big anchor tabs and it is the one feature that can take
//   a shove. So the cradle uses it as the datum, and everything else just stops
//   the board rattling.
//
//     plugging a cable IN   pushes the board deeper  -> a hard stop behind the
//                                                       far end takes it
//     pulling a cable OUT   drags the board forward  -> the entry lip takes it
//     everything else       lift/rattle              -> the side slots take it
//
//   Get this backwards — retain the far end and leave the USB end floating —
//   and every insertion levers the connector off its pads. That is the usual
//   way these boards die.
//
// SLIDES IN FROM THE BACK, USB-C END FIRST, before the panel goes in.
//
// ⚠ DIMENSIONS ARE FROM PHOTOGRAPHS AND DATASHEET-TYPICALS, NOT MEASURED.
//   Caliper the four marked CHECK values before printing anything.
// =============================================================================

// ---------- ESP32-C3 Super Mini ----------
esp_w       = 18.0;    // CHECK  across the castellated rows
esp_l       = 22.5;    // CHECK  along the USB axis
esp_t       = 1.2;     // CHECK  pcb only
mod_w       = 12.0;    // the shielded module can
mod_l       = 13.0;
mod_t       = 1.6;
usb_w       = 8.94;    // CHECK  USB-C receptacle shell
usb_t       = 3.26;
usb_proud   = 1.6;     // how far it oversails the board edge
btn_w       = 3.5;     // RST and BOOT, either side of centre
btn_l       = 2.9;
btn_t       = 1.7;
btn_gap     = 2.0;     // between the two buttons

// ---------- fit ----------
slack       = 0.35;    // per side, board to slot
slot_grip   = 1.2;     // how far the side slots overlap the pcb edge
floor_t     = 1.6;
rail_t      = 2.2;     // material under the board, above the floor
wall        = 2.0;
btn_clear   = 1.0;     // air above the buttons so nothing presses them

// ---------- wiring ----------
// Three wires only: 5V, GND, one data. On this board 5V and G are adjacent on
// the right-hand row, with GPIO 0-4 directly below them, so all three land on
// ONE edge and the loom leaves as a single bundle.
wire_d      = 1.6;     // 22 AWG with insulation
wire_n      = 3;

// "cradle" | "fitted" | "section" | "exploded" | "esp"
mode = "fitted";

// ---------- derived ----------
pocket_w    = esp_w + 2 * slack;
pocket_l    = esp_l + 2 * slack;
z_board     = floor_t + rail_t;                 // underside of the pcb
z_top       = z_board + esp_t;                  // top face of the pcb
cradle_h    = z_top + max(usb_t, mod_t, btn_t + btn_clear) + 1.0;

// =============================================================================
// THE BOARD ITSELF — modelled so the clearances can be seen, not guessed
// =============================================================================
module esp32_c3() {
    // pcb
    color([0.10, 0.10, 0.12]) cube([esp_w, esp_l, esp_t]);
    // castellated pads, 8 per side at 2.54
    color([0.85, 0.70, 0.30])
        for (s = [0, 1], i = [0 : 7])
            translate([s ? esp_w - 0.9 : 0, 2.2 + i * 2.54, 0])
                cube([0.9, 1.6, esp_t]);
    // shielded module
    color([0.55, 0.55, 0.58])
        translate([(esp_w - mod_w) / 2, esp_l - mod_l - 3.5, esp_t]) cube([mod_w, mod_l, mod_t]);
    // RST / BOOT — these sit between the module and the USB end, which is why
    // the cradle cannot simply be a closed box at this end.
    color([0.80, 0.80, 0.82])
        for (k = [0, 1])
            translate([esp_w / 2 - btn_w - btn_gap / 2 + k * (btn_w + btn_gap), esp_l - mod_l - 3.5 - btn_l - 1.2, esp_t])
                cube([btn_w, btn_l, btn_t]);
    // USB-C receptacle, overhanging the near edge
    color([0.75, 0.75, 0.78])
        translate([(esp_w - usb_w) / 2, -usb_proud, esp_t]) cube([usb_w, 7.0 + usb_proud, usb_t]);
}

// =============================================================================
// THE CRADLE
// =============================================================================
module cradle() {
    difference() {
        union() {
            // floor + outer walls, open at the top and at the far (entry) end
            cube([pocket_w + 2 * wall, pocket_l + wall, cradle_h]);
        }

        // the pocket the board lives in
        translate([wall, 0, floor_t]) cube([pocket_w, pocket_l + 0.1, cradle_h]);

        // slots: the board slides in edgewise and cannot lift out
        translate([wall - slot_grip, 0, z_top]) cube([slot_grip + 0.1, pocket_l + 0.1, cradle_h]);
        translate([wall + pocket_w - 0.1, 0, z_top]) cube([slot_grip + 0.1, pocket_l + 0.1, cradle_h]);

        // USB-C aperture through the end wall. Deliberately a CLOSE fit on the
        // shell: this is the feature that locates the board, so slop here means
        // a board that waggles every time a cable goes in.
        translate([wall + (pocket_w - usb_w) / 2 - 0.3, -1, z_top - 0.3])
            cube([usb_w + 0.6, wall + 2, usb_t + 0.6]);

        // relief so a plug's overmould does not foul the outside of the wall
        translate([wall + (pocket_w - usb_w) / 2 - 2.2, -1, z_top - 2.0])
            cube([usb_w + 4.4, 1.4, usb_t + 4.0]);

        // wire exit — one bundle off the right-hand row
        translate([wall + pocket_w - 1.0, pocket_l - wire_n * (wire_d + 0.6) - 2, z_board - 0.4])
            cube([wall + 2, wire_n * (wire_d + 0.6), wire_d + 1.2]);
    }

    // Hard stop behind the far end. This — not the slots — is what absorbs the
    // shove of plugging a cable in.
    translate([wall, pocket_l - 0.6, floor_t]) cube([pocket_w, 0.6, rail_t + esp_t + 0.8]);

    // Entry lip: a small cantilever that the board clicks past going in, and
    // that stops it walking back out when a cable is pulled.
    translate([wall + pocket_w / 2 - 3, pocket_l - 0.6, z_top])
        cube([6, 0.6, 1.2]);
}

// =============================================================================
module fitted() {
    cradle();
    translate([wall + slack, slack, z_board]) esp32_c3();
}

if (mode == "esp") {
    esp32_c3();
} else if (mode == "cradle") {
    cradle();
} else if (mode == "exploded") {
    cradle();
    translate([wall + slack, slack, z_board + 16]) esp32_c3();
} else if (mode == "section") {
    difference() {
        fitted();
        translate([-1, -20, -1]) cube([(pocket_w + 2 * wall) / 2 + 1, 60, 40]);
    }
} else {
    fitted();
}

echo(str("cradle  ", pocket_w + 2 * wall, " x ", pocket_l + wall, " x ", cradle_h, " mm"));
echo(str("board sits at z ", z_board, "..", z_top, "   usb aperture z ", z_top - 0.3, "..", z_top + usb_t + 0.3));
echo(str("tallest thing above the pcb: ", max(usb_t, mod_t, btn_t + btn_clear), " mm"));
