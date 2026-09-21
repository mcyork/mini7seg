// =============================================================================
// mini7seg_enclosure_v1.scad
//
// ROUGH CONCEPT. Massing study for a 4-digit enclosure, not a printable part.
// Numbers here are placeholders to be argued with; only the board geometry is
// real, and that comes from mini7seg_diffuser_v5.scad which reads it off the
// PCB.
//
// THE STACK, front (viewer) to back:
//
//     clear window      1.8   one rectangle over all four digits, + margin
//     black baffle      4.0   light wells, from v5
//   --------------------------  boards sit LED-side FORWARD, against the baffle
//     pcb               1.6   heat-stake posts pass through it and rivet here
//     cavity           10.0   wiring + ESP32 live here
//     back wall         2.0
//
// Z CONVENTION: +Z is the viewer, matching mini7seg_diffuser_v5.scad exactly —
// baffle 0..4, diffuser above it, posts hanging to NEGATIVE z through the pcb.
// Building this the other way up put the posts out through the window.
//
// ONE COLOUR CHANGE. The part prints window-face-down and swaps filament
// exactly once, so the rule is absolute:
//
//     below the seam  ->  ALL clear
//     above the seam  ->  ALL black
//
// That is why the window is the FULL OUTER rectangle rather than just the
// aperture, and why the walls start on top of it instead of running past it to
// the bed. A wall that reached the bed would put black under the seam and cost
// a second change.
//
// The board is flipped relative to how you photographed it: LEDs face the
// window, so the bare back of the PCB faces the cavity and every solder joint
// and wire is on the side you can reach.
//
// WHAT IS DELIBERATELY UNRESOLVED (needs your call):
//   - how the boards are retained. v5's heat-stake posts still work — they pass
//     through from the front and rivet on the back, inside the cavity — but an
//     enclosure could instead just trap the panel between baffle and a rib and
//     skip the posts entirely. Posts are shown; ribs are not.
//   - ESP32 footprint is a placeholder block. Measure yours.
//   - no fixings, no lid retention, no cable exit yet.
// =============================================================================

use <mini7seg_diffuser_v5.scad>

// ---------- from the PCB (see v5 header) ----------
board_w        = 20.32;
board_h        = 34.29;
pcb_t          = 1.6;
digits         = 4;
pitch          = board_w;          // V-cut snapped tight, no rail between digits

// ---------- stack ----------
window_t       = 1.8;              // clear
baffle_t       = 4.0;              // opaque
// Free-wired, no headers: the tallest thing behind the panel is the ESP32's
// USB-C shell at 3.26 mm above its pcb. 5 mm carries it with room for the loom.
cavity         = 5.0;              // wiring + ESP32, no headers
back_t         = 0.0;              // no backing
wall           = 2.0;

// ---------- how far the window oversails the boards ----------
margin         = 3.0;

// ---------- ESP32-C3 Super Mini (identified from photo) ----------
// 22.5 x 18 mm board. Trivially small next to the 81 x 34 panel — the
// constraint is not its footprint, it is its HEIGHT once headers are on.
esp_w          = 18.0;             // across the header rows
esp_l          = 22.5;             // along the USB axis
esp_pcb_t      = 1.2;
esp_parts_t    = 2.0;              // module can + USB shell above the pcb
// Male pin headers are fitted in the photo. Those pins stand ~6 mm proud below
// the board plus a 2.5 mm spacer, and that is what sets the cavity, not the
// electronics. Set headers = false if they come off / wires go straight to the
// castellations, and the cavity can close up by ~8 mm.
headers        = false;
esp_hdr_t      = headers ? 8.5 : 0;
esp_t          = esp_pcb_t + esp_parts_t + esp_hdr_t;

// USB-C shell, for the port cutout. Protrudes slightly past the board edge.
usb_w          = 9.0;
usb_t          = 3.3;
usb_proud      = 1.6;

// ---------- derived ----------
boards_w       = digits * pitch;                 // 81.28
inner_w        = boards_w + 2 * margin;
inner_h        = board_h + 2 * margin;
outer_w        = inner_w + 2 * wall;
outer_h        = inner_h + 2 * wall;
depth          = window_t + baffle_t + pcb_t + cavity + back_t;

// Board array is centred on digit 0's local origin, so shift the whole stack so
// the four digits sit centred in the shell.
board_dx       = -(digits - 1) * pitch / 2;

// "assembled" | "exploded" | "section" | "front" | "body"
mode = "assembled";
explode = (mode == "exploded") ? 14 : 0;

// =============================================================================
// Stack levels, all in v5's frame: +Z toward the viewer.
z_win_lo   = baffle_t;                       // window sits on the baffle face
z_pcb_hi   = 0;                              // pcb hard against the baffle back
z_pcb_lo   = -pcb_t;
z_cav_lo   = z_pcb_lo - cavity;
z_back_lo  = z_cav_lo - back_t;
z_top      = z_win_lo + window_t;

module rounded(w, h, t) { linear_extrude(t) offset(r = 2) square([w - 4, h - 4], center = true); }

// Full outer footprint: everything below the seam is this plate and nothing
// else. The walls land on it.
module window_plate() {
    color([1, 1, 1, 0.30]) translate([0, 0, z_win_lo]) rounded(outer_w, outer_h, window_t);
}

module baffle_stack() {
    color([0.12, 0.12, 0.12]) translate([board_dx, 0, 0]) multi_digit_baffle();
}

module pcb_panel() {
    color([0.05, 0.25, 0.10])
        translate([board_dx - board_w / 2, -board_h / 2, z_pcb_lo])
            cube([boards_w, board_h, pcb_t]);
}

// ESP32-C3 Super Mini in the cavity, USB-C facing the bottom edge so a cable
// exits the long side rather than an end. Sits against the back wall, headers
// pointing back toward the pcb.
esp_x  = inner_w / 2 - esp_w - 5;        // tucked behind the right-hand digits
esp_y0 = -inner_h / 2;                   // USB end flush with the bottom wall
module esp32() {
    color([0.15, 0.35, 0.65])
        translate([esp_x, esp_y0, z_cav_lo + 0.1]) {
            cube([esp_w, esp_l, esp_t]);
            // USB-C shell poking out through the wall
            translate([(esp_w - usb_w) / 2, -usb_proud - 1, esp_hdr_t])
                cube([usb_w, usb_proud + 2, usb_t]);
        }
}

// The hole the USB-C plug goes through. Generous — a plug overmould is much
// bigger than the shell.
module usb_cutout() {
    translate([esp_x + (esp_w - usb_w) / 2 - 1.5, -outer_h, z_cav_lo + 0.1 + esp_hdr_t - 1])
        cube([usb_w + 3, outer_h, usb_t + 2]);
}

// Wall ring only — no back. Stops at the window's inner face so the seam is a
// single clean plane. Open at the rear: the panel and the ESP32 go in from
// behind and the wiring stays reachable.
module shell() {
    color([0.30, 0.30, 0.32])
        difference() {
            translate([0, 0, z_back_lo]) rounded(outer_w, outer_h, z_win_lo - z_back_lo);
            translate([0, 0, z_back_lo - 1]) rounded(inner_w, inner_h, z_win_lo - z_back_lo + 1);
            usb_cutout();
        }
}

// No back wall — Ian's call. The case is a tray: window, baffle, wall ring.
module back_wall() { }

module assembly() {
    translate([0, 0,  explode * 2]) window_plate();
    translate([0, 0,  explode])     baffle_stack();
    pcb_panel();
    esp32();
    translate([0, 0, -explode])     back_wall();
    shell();
}

if (mode == "front") {
    window_plate(); baffle_stack();
} else if (mode == "body") {
    shell(); back_wall();
} else if (mode == "section") {
    difference() {
        assembly();
        translate([-outer_w, -outer_h, -60]) cube([outer_w * 2, outer_h, 120]);
    }
} else {
    assembly();
}

echo(str("outer  ", outer_w, " x ", outer_h, " x ", z_top - z_back_lo, " mm"));
echo(str("inner  ", inner_w, " x ", inner_h, " mm   cavity ", cavity, " mm"));
echo(str("esp32  ", esp_w, " x ", esp_l, " x ", esp_t, " mm   headers=", headers, "  -> needs ", esp_t + 1, " of the ", cavity, " cavity"));
echo(str("z: back ", z_back_lo, "  pcb ", z_pcb_lo, "..", z_pcb_hi, "  baffle 0..", baffle_t, "  window top ", z_top));
