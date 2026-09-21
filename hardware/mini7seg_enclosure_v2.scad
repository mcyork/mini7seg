// =============================================================================
// mini7seg_enclosure_v2.scad
//
// PRINTABLE. Unlike v1 (a massing study) this is a part.
//
//   clear rectangular window  +  black baffle with light wells  +  heat-stake
//   posts  +  a wall ring deep enough to press the panel into.
//
// No clips anywhere. The posts locate and retain; the walls just surround.
//
// AUTHORED IN v5's FRAME: +Z IS THE VIEWER.
//     z  4.00 ..  5.80   CLEAR   window
//     z  0.00 ..  4.00   BLACK   baffle, light wells
//     z -1.60 ..  0.00           panel (LEDs facing +Z, into the baffle)
//     z -3.20 ..  0.00   BLACK   posts, through the panel, riveted behind
//     z -8.80 ..  4.00   BLACK   wall ring
//
//   This matters more than bookkeeping. The first cut of this file was authored
//   upside down — viewer at -Z — while reusing v5's pockets, which assume the
//   viewer at +Z. Reusing geometry across a Z flip MIRRORS it, and the decimal
//   points came out on the wrong side of every digit. The part looked fine in
//   every render until you looked up through the window.
//   One frame, owned by the file that owns the board geometry. Print
//   orientation is Build.ts's job, not the model's.
//
// PRINTS WINDOW-FACE-DOWN — Build.ts flips the whole thing, exactly as it does
// for the cover, so the clear lands on the sheet and the posts point up.
//
// THE BAFFLE IS A SLAB, NOT FOUR SILHOUETTES
//   v5's cover traced each digit's outline because it had nothing else to hold
//   on to. Inside a case that is the wrong shape: a rectangular slab gives the
//   panel a continuous flat face to press against, and the pockets are still
//   cut from the same v5 geometry, so the wells stay derived from the PCB.
//
// ⚠ Panel pocket is a SLIP fit, not an interference fit, on purpose. The posts
//   go through 2.50 mm holes with 0.125 mm of side play; a wall that also
//   gripped the board edges would fight them and something would have to give.
//   Posts locate, walls protect. Tighten pocket_fit only if you drop the posts.
// =============================================================================

use <mini7seg_diffuser_v5.scad>

// ---------- panel, from the PCB ----------
board_w     = 20.32;
board_h     = 34.29;
pcb_t       = 1.6;
digits      = 4;
pitch       = board_w;
panel_w     = digits * pitch;        // 81.28
panel_h     = board_h;               // 34.29

// ---------- stack ----------
window_t    = 1.8;                   // clear
baffle_t    = 4.0;                   // must match v5's baffle_thickness
// 7.0, not 6.0. The USB-C aperture has to be a CLOSED hole for anything to
// press into it, and that needs material above the shell. At cavity 6.0 the
// wall ran out 0.04 mm above the connector — an open notch, nothing to grip.
// 7.0 leaves ~1.0 mm of wall over the hole, which bridges fine and gives the
// press fit something to be a fit against.
cavity      = 7.2;                   // behind the panel: ESP32 + loom
wall        = 2.0;

// ---------- USB-C aperture, long bottom edge ----------
// The ESP32 is not retained by anything in this part — no cradle, no clips.
// The connector poking through a snug hole plus glue IS the mounting, which is
// why the aperture is sized to the shell rather than to a plug.
usb_x       = 30.48;                 // behind the rightmost digit
usb_w       = 8.94;                  // CHECK  shell width
usb_h       = 3.26;                  // CHECK  shell height
usb_clear   = 0.20;                  // total, both axes — press fit, not slip
// ESP32 stack, from the panel's back face, deciding where the hole sits in z
solder_gap  = 1.5;                   // H1/H2 joints on the panel back
esp_pcb_t   = 1.2;

// ---------- fits ----------
// 0.75, was 0.25. The first article printed too tight to seat the panel —
// measured, not guessed: Ian asked for half a millimetre more on every side.
// FDM walls come in thicker than nominal on an inside corner, so a pocket that
// computes to a fit does not necessarily print as one.
pocket_fit  = 0.75;                  // per side, panel to wall
corner_r    = 2.0;

// ---------- derived ----------
pocket_w    = panel_w + 2 * pocket_fit;
pocket_h    = panel_h + 2 * pocket_fit;
outer_w     = pocket_w + 2 * wall;
outer_h     = pocket_h + 2 * wall;
// v5 frame: baffle occupies 0..baffle_t, everything else hangs off that.
z_win_lo    = baffle_t;                 // window sits on the baffle's front face
z_win_hi    = z_win_lo + window_t;
z_panel_hi  = 0;                        // panel hard against the baffle back
z_panel_lo  = -pcb_t;
z_back      = z_panel_lo - cavity;      // open rear lip of the wall

// Digit i sits at x = i*pitch in v5's frame, each digit board-centred, so the
// array spans -board_w/2 .. (digits-1)*pitch + board_w/2. Shift to centre it.
array_dx    = -((digits - 1) * pitch) / 2;

// "part" | "window" | "black" | "section" | "fitted"
mode = "part";

// =============================================================================
module rounded(w, h, t, r = corner_r) {
    linear_extrude(t) offset(r = r) square([w - 2 * r, h - 2 * r], center = true);
}

// ---- CLEAR: the whole face, one plate ----
module window() {
    translate([0, 0, z_win_lo]) rounded(outer_w, outer_h, window_t);
}

// ---- BLACK ----
module baffle() {
    translate([0, 0, 0])
        difference() {
            rounded(pocket_w, pocket_h, baffle_t, 1.0);
            // Wells cut from v5 so they stay tied to the PCB geometry.
            translate([array_dx, 0, 0])
                for (i = [0 : digits - 1])
                    translate([i * pitch, 0, 0]) single_digit_pockets();
        }
}

module posts() {
    // No mirror, no offset — v5 already hangs these to negative z through the
    // panel. That is the point of sharing its frame.
    translate([array_dx, 0, 0])
        for (i = [0 : digits - 1])
            translate([i * pitch, 0, 0]) single_digit_posts();
}

// Where the USB-C shell lands: behind the panel, behind the solder fillets,
// behind the ESP's own pcb, components facing the open back.
z_usb_hi    = z_panel_lo - solder_gap - esp_pcb_t;
z_usb_lo    = z_usb_hi - usb_h - usb_clear;

module usb_aperture() {
    // Through the bottom long wall. Closed on all four sides.
    translate([usb_x, -outer_h / 2 - 1, z_usb_lo])
        cube([usb_w + usb_clear, wall + 2, usb_h + usb_clear], center = false);
    // Outside relief so a plug's overmould does not foul the face.
    translate([usb_x - 2.0, -outer_h / 2 - 1, z_usb_lo - 1.8])
        cube([usb_w + usb_clear + 4.0, 1.2, usb_h + usb_clear + 3.6]);
}

module walls() {
    translate([0, 0, z_back])
        difference() {
            rounded(outer_w, outer_h, z_win_lo - z_back);
            translate([0, 0, -0.1]) rounded(pocket_w, pocket_h, z_win_lo - z_back + 0.2, 1.0);
        }
}

module walls_cut() {
    difference() { walls(); translate([-usb_w / 2 - usb_clear / 2, 0, 0]) usb_aperture(); }
}

module black_parts() { baffle(); walls_cut(); posts(); }

// =============================================================================
if (mode == "window") window();
else if (mode == "black") black_parts();
else if (mode == "section")
    difference() {
        union() { color([1,1,1,0.35]) window(); color([0.12,0.12,0.12]) black_parts(); }
        translate([-outer_w, -outer_h, -1]) cube([outer_w * 2, outer_h, 60]);
    }
else if (mode == "fitted") {
    color([1,1,1,0.35]) window();
    color([0.12,0.12,0.12]) black_parts();
    color([0.05,0.25,0.10]) translate([-panel_w/2, -panel_h/2, z_panel_lo]) cube([panel_w, panel_h, pcb_t]);
} else {
    color([1,1,1,0.35]) window();
    color([0.12,0.12,0.12]) black_parts();
}

echo(str("outer   ", outer_w, " x ", outer_h, " x ", z_win_hi - z_back, " mm"));
echo(str("pocket  ", pocket_w, " x ", pocket_h, " mm  (panel ", panel_w, " x ", panel_h, ", ", pocket_fit, "/side)"));
echo(str("usb hole: x ", usb_x, "  z ", z_usb_lo, "..", z_usb_hi, "   wall beyond it ", z_usb_lo - z_back, " mm"));
echo(str("v5 frame: window ", z_win_lo, "..", z_win_hi, " | baffle 0..", baffle_t, " | panel ", z_panel_lo, "..0 | rear ", z_back));
