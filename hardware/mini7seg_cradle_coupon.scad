// =============================================================================
// mini7seg_cradle_coupon.scad
//
// Fit-and-feel coupon for the ESP32-C3 cradle. Nine cradles on one plate, every
// one holding the same real board, so the answer comes from clicking the module
// in and out rather than from arithmetic.
//
// WHAT VARIES, AND WHY THESE TWO
//   columns  fit      0.20 / 0.30 / 0.40 mm per side
//            Pocket slack is the most printer-dependent number in the part.
//            The same G-code on two machines differs by more than this range,
//            which is exactly why it cannot be computed — hence a coupon, and
//            hence one coupon PER PRINTER.
//   rows     clip_t   1.0 / 1.2 / 1.4 mm
//            Clip stiffness goes as t^3, so 1.0 -> 1.4 is nearly a 3x change in
//            insertion force. This is the "clicks in nicely" vs "needs a thumb"
//            axis.
//
//   clip_l stays at 11 mm throughout. Strain is 3*t*d/(2*L^2), so shortening the
//   clip is what breaks it, and that is not a variable worth risking on a part
//   meant to be opened repeatedly. At L=11 the three thicknesses give 1.24%,
//   1.49% and 1.74% — all comfortably under PETG's ~4-5% yield.
//
// HOW TO READ IT
//   Click the board into every cell. For each, judge:
//     L  falls out / rattles          -> fit too big
//     G  clicks, holds, releases with a fingernail
//     T  needs a tool, or will not seat -> fit too small or clip too thick
//   The answer is the LOOSEST cell that still scores G — it will only get
//   tighter with a cold plate or a new roll.
//
//   Print one per printer. Write the machine on the plate with a marker; the
//   cell labels tell you the rest.
//
// ⚠ Cells are open-backed on purpose: no USB slot, no push-hole, no back plate.
//   This coupon answers "does it click" only. It does NOT check USB alignment —
//   that needs the real cradle once fit and clip_t are chosen.
// =============================================================================

use <mini7seg_esp_cradle_v2.scad>

fits    = [0.20, 0.30, 0.40];
thicks  = [1.0, 1.2, 1.4];

cell_x  = 30;
cell_y  = 34;
base_t  = 1.6;
label_h = 0.6;

cols = len(fits);
rows = len(thicks);
plate_x = cols * cell_x + 8;
plate_y = rows * cell_y + 12;

module label(txt, size = 3.4) {
    linear_extrude(label_h) text(txt, size = size, halign = "center", font = "Helvetica:style=Bold");
}

module plate() {
    difference() {
        translate([-4, -6, -base_t]) cube([plate_x, plate_y, base_t]);
        // shallow grip slots so the coupon can be snapped off the bed easily
        for (i = [0 : cols]) translate([i * cell_x - 4.5, -7, -base_t - 1]) cube([1, plate_y + 2, 0.8]);
    }
}

module coupon() {
    plate();
    for (c = [0 : cols - 1], r = [0 : rows - 1]) {
        translate([c * cell_x + 3, r * cell_y + 2, 0]) {
            // The cradle's frame puts z=0 at the PANEL BACK and builds rearward,
            // so its lowest face is at -(cavity + wall). Lift by exactly that or
            // the back plate buries itself in the coupon base and the pocket
            // comes out too shallow to hold anything.
            translate([0, 0, 5.96 + 1.8])
                cradle(clip_t = thicks[r], clip_grab = 1.0, fit = fits[c]);
            // cell id, e.g. "30/1.2" = 0.30 fit, 1.2 clip
            translate([9, -4.4, 0])
                label(str(fits[c] * 100, "/", thicks[r]), 3.0);
        }
    }
    // axis legends
    translate([plate_x / 2 - 4, plate_y - 10, 0]) label("FIT -->", 4);
}

coupon();

echo(str("coupon plate: ", plate_x, " x ", plate_y, " mm   cells: ", cols * rows));
echo(str("clip strain by row (%):"));
for (t = thicks) echo(str("   t=", t, "  ", 100 * 3 * t * 1.0 / (2 * 11 * 11), " %"));
