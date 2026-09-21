// =============================================================================
// mini7seg_esp_cradle_v2.scad
//
// ESP32-C3 Super Mini cradle, far right of the enclosure, USB-C pointing DOWN
// so a wall-mounted case lets the cable hang straight. No rivets anywhere.
//
// WHY THE CLIPS FLEX SIDEWAYS AND NOT BACKWARDS
//   The case prints window-face-down, so every layer line lies in XY. A clip
//   that flexes in Z is being asked to pull its own layers apart — the single
//   weakest direction in FDM, and PETG's layer bond is where it breaks. A clip
//   that flexes in X or Y bends ALONG the layers instead, which is solid
//   material doing what it is good at.
//   So: the board pushes in toward the window (+Z) past two side clips that
//   deflect outward in X, and they snap over its back face.
//
// CLIP SIZING, not guessed
//   Cantilever surface strain  e = 3*t*d / (2*L^2)
//     t 1.2 mm thick, d 1.0 mm deflection, L 11 mm long
//     e = 3(1.2)(1.0) / (2*121) = 1.5%
//   PETG yields around 4-5%, so 1.5% is a clip that can be worked repeatedly
//   rather than one that survives two insertions. A short stiff clip is what
//   snaps: at L = 6 the same deflection gives 5% and it breaks.
//
// EASY OUT
//   One finger notch either side of each clip so a fingernail reaches the pad,
//   and a push-through hole under the board so a probe can pop it from the
//   front if it ever seizes.
//
// DEPTH
//   Minimum practical stack behind the panel:
//     panel back            0.0   (local datum)
//     solder clearance      1.5   H1/H2 joints stand proud; this is NOT air
//     esp pcb               1.2
//     usb shell / can       3.3
//                          ----
//                           6.0   total cavity
//
// ⚠ CHECK-marked values are from photographs, not calipers.
// =============================================================================

// ---------- ESP32-C3 Super Mini ----------
esp_w       = 18.0;    // CHECK  across the castellated rows  (horizontal here)
esp_l       = 22.5;    // CHECK  along the USB axis           (vertical here)
esp_t       = 1.2;     // CHECK  pcb only
usb_w       = 8.94;    // CHECK  receptacle shell
usb_t       = 3.26;    // CHECK
usb_proud   = 1.6;     // oversail past the board edge
mod_t       = 1.6;
btn_t       = 1.7;

// ---------- stack ----------
solder_gap  = 1.5;     // panel-back solder fillets, the real floor of the cavity
fit         = 0.3;     // per side, board to pocket

// ---------- clips ----------
clip_l      = 11.0;    // long enough to keep strain at 1.5%
clip_t      = 1.2;
clip_grab   = 1.0;     // how far it overlaps the board's back face
clip_ramp   = 1.2;     // lead-in so it pushes in with a thumb
notch_w     = 5.0;     // fingernail access beside each clip

wall        = 1.8;
rail        = 1.2;     // ledge the board's front face rests on

// ---------- derived (local frame: z=0 is the PANEL BACK, -z goes rearward) ----
z_esp_front = -solder_gap;
z_esp_back  = z_esp_front - esp_t;
z_parts     = z_esp_back - max(usb_t, mod_t, btn_t);
pocket_w    = esp_w + 2 * fit;
pocket_l    = esp_l + 2 * fit;

mode = "fitted";   // fitted | cradle | section | released | esp

// =============================================================================
module esp32_c3() {
    color([0.10, 0.10, 0.12]) cube([esp_w, esp_l, esp_t]);
    color([0.85, 0.70, 0.30])
        for (s = [0, 1], i = [0 : 7])
            translate([s ? esp_w - 0.9 : 0, 2.2 + i * 2.54, 0]) cube([0.9, 1.6, esp_t]);
    color([0.55, 0.55, 0.58])
        translate([(esp_w - 12) / 2, esp_l - 16, -1.6]) cube([12, 13, 1.6]);
    // USB-C at the BOTTOM edge, shell on the component side, oversailing -Y
    color([0.75, 0.75, 0.78])
        translate([(esp_w - usb_w) / 2, -usb_proud, -usb_t]) cube([usb_w, 7 + usb_proud, usb_t]);
}

// A single side clip. Root at the back, finger pad at the open end.
module clip(mirrored = false, clip_t = clip_t, clip_grab = clip_grab, clip_l = clip_l) {
    mirror([mirrored ? 1 : 0, 0, 0])
    translate([-clip_t, 0, 0]) {
        // the flexing beam, lying in the XY plane so it bends along layers
        cube([clip_t, clip_l, abs(z_parts) + 1]);
        // the grab: overlaps the board's back face
        translate([clip_t - 0.01, clip_l * 0.25, 0])
            cube([clip_grab, clip_l * 0.5, abs(z_esp_back) + 0.8]);
        // lead-in ramp, so pushing the board in spreads the clip
        translate([clip_t, clip_l * 0.25, abs(z_esp_back) + 0.8])
            rotate([0, 0, 0])
                linear_extrude(clip_l * 0.5)
                    polygon([[0, 0], [clip_grab, 0], [0, clip_ramp]]);
        // finger pad
        translate([-0.8, clip_l - 2.5, 0]) cube([0.8, 2.5, abs(z_parts) + 1]);
    }
}

module cradle(clip_t = clip_t, clip_grab = clip_grab, fit = fit) {
    pocket_w = esp_w + 2 * fit;
    pocket_l = esp_l + 2 * fit;
    difference() {
        union() {
            // back plate the ESP sits against + side walls
            translate([-wall, -wall, z_parts - wall])
                cube([pocket_w + 2 * wall, pocket_l + wall, wall]);
            translate([-wall, -wall, z_parts - wall])
                cube([wall, pocket_l + wall, abs(z_parts) + 1 - wall]);
            translate([pocket_w, -wall, z_parts - wall])
                cube([wall, pocket_l + wall, abs(z_parts) + 1 - wall]);
            // hard stop at the TOP — plugging a cable in drives the board up,
            // and this is what takes it, not the clips.
            translate([-wall, pocket_l, z_parts - wall])
                cube([pocket_w + 2 * wall, wall, abs(z_parts) + 1 - wall]);
            // front rails the board's face lands on
            translate([0, 0, z_esp_front])
                cube([rail, pocket_l, rail]);
            translate([pocket_w - rail, 0, z_esp_front])
                cube([rail, pocket_l, rail]);
        }
        // USB slot: open toward the REAR so the board lifts straight out once
        // the clips are released. A closed hole would trap it.
        translate([(pocket_w - usb_w) / 2 - 0.4, -wall - 1, z_esp_back - usb_t - 0.4])
            cube([usb_w + 0.8, wall + 2, usb_t + 0.8 + 6]);
        // fingernail notches beside each clip
        for (x = [-wall - 0.1, pocket_w - 0.1])
            translate([x, clip_l - notch_w, z_parts - wall - 0.1])
                cube([wall + 0.2, notch_w, abs(z_parts) + 2]);
        // push-through hole: pop the board from the front with a probe
        translate([pocket_w / 2, pocket_l * 0.6, z_parts - wall - 1])
            cylinder(d = 4, h = wall + 2, $fn = 32);
    }
    // the two clips
    translate([0, 0, z_parts]) clip(false, clip_t, clip_grab, clip_l);
    translate([pocket_w, 0, z_parts]) clip(true, clip_t, clip_grab, clip_l);
}

module fitted() { cradle(); translate([fit, fit, z_esp_back]) esp32_c3(); }

if (mode == "esp") esp32_c3();
else if (mode == "cradle") cradle();
else if (mode == "released") { cradle(); translate([fit, fit, z_esp_back + 9]) esp32_c3(); }
else if (mode == "section")
    difference() { fitted(); translate([pocket_w / 2, -30, -40]) cube([60, 90, 80]); }
else fitted();

echo(str("cavity behind panel: ", -z_parts, " mm   (solder ", solder_gap, " + pcb ", esp_t, " + parts ", max(usb_t, mod_t, btn_t), ")"));
echo(str("cradle envelope: ", pocket_w + 2 * wall, " x ", pocket_l + wall, " mm"));
echo(str("clip strain at ", clip_grab, " mm deflection: ", 100 * 3 * clip_t * clip_grab / (2 * clip_l * clip_l), " %"));
