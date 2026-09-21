// =============================================================================
// mini7seg_diffuser_v2.scad
// Iteration 2: digit-silhouette outline + thin mount base + push-fit snap clips.
//
// Differences from v1 (mini7seg_diffuser.scad):
//   1. Outer profile is a "figure-8" digit silhouette (hull of A/F/B/G + hull of
//      G/E/C/D, joined to DP), not a rectangle. Looks like an actual 7-seg
//      digit when sitting on the PCB.
//   2. A thin (~0.6 mm) base layer extends the silhouette slightly to capture
//      the mount-hole positions cleanly. Body above the base is the visible
//      digit shape with hex pockets (LED tubes) for the baffle, or solid for
//      the diffuser.
//   3. Adds an optional push-mount snap clip (drywall-anchor style — already
//      expanded, you press it through the hole and the barbs spring out on the
//      far side). Print 2 per digit if used.
//
// CAVEATS
//   - The snap clip's geometry is a starting point. Tolerance and barb
//     compressibility depend hugely on filament + printer + slot resolution.
//     Expect to print v1, measure, tweak `clip_*` constants, reprint.
//   - All segment positions and mount-hole Y values still derived from
//     ../images/pcb-design.png, not gerbers — verify on a real board.
// =============================================================================


// ---------- BOARD ----------
board_w        = 20.2;
board_h        = 34.3;
pcb_thickness  = 1.6;       // standard 2-layer JLCPCB

header_zone_top = 4.0;
header_zone_bot = 4.0;

mount_hole_d        = 3.2;
mount_hole_y_top    =  5.5;
mount_hole_y_bot    = -5.5;


// ---------- SEGMENT GEOMETRY ----------
seg_length  = 7.0;
seg_width   = 2.4;
seg_chamfer = 0.9;


// ---------- DIGIT LAYOUT (same as v1) ----------
seg_A = [ 0,    11.0,   0];
seg_B = [ 4.5,  6.0,   90];
seg_C = [ 4.5, -6.0,   90];
seg_D = [ 0,   -11.0,   0];
seg_E = [-4.5, -6.0,   90];
seg_F = [-4.5,  6.0,   90];
seg_G = [ 0,    0.0,    0];

dp_pos = [ 7.5, -10.0];
dp_d   = 2.0;


// ---------- LAYER STACK ----------
baffle_thickness   = 4.0;     // total baffle height (base + body)
baffle_base_t      = 0.6;     // thin base layer carrying the mount holes
diffuser_thickness = 1.2;
silhouette_margin  = 1.0;     // outer wall around segments (mm)


// ---------- SNAP CLIP ----------
clip_cap_d         = 5.0;     // top cap that sits on the diffuser
clip_cap_h         = 1.2;
clip_stem_d        = mount_hole_d - 0.2;   // slip fit through hole
clip_barb_max_d    = 4.5;     // splayed barb diameter (must exceed mount_hole_d)
clip_barb_h        = 1.5;
clip_slit_w        = 0.5;     // compressibility slit (printable minimum)
clip_slit_into_stem = 1.0;    // how far the slit extends up into the stem


// ---------- RENDER MODE ----------
// One of: "baffle", "diffuser", "clip", "preview"
mode = "preview";


// =============================================================================
// 2D PRIMITIVES
// =============================================================================

module hex_bar_2d(length, width, chamfer) {
    polygon(points = [
        [-length/2 + chamfer, -width/2],
        [ length/2 - chamfer, -width/2],
        [ length/2,            0      ],
        [ length/2 - chamfer,  width/2],
        [-length/2 + chamfer,  width/2],
        [-length/2,            0      ],
    ]);
}

module hex_bar_at(seg) {
    translate([seg[0], seg[1]])
        rotate(seg[2])
            hex_bar_2d(seg_length, seg_width, seg_chamfer);
}

// Digit silhouette: figure-8 of two hulls + DP appendage, grown by margin.
module digit_silhouette() {
    offset(r = silhouette_margin) {
        union() {
            // Upper "0": hull of A, F, B, G
            hull() {
                hex_bar_at(seg_A);
                hex_bar_at(seg_F);
                hex_bar_at(seg_B);
                hex_bar_at(seg_G);
            }
            // Lower "0": hull of G, E, C, D
            hull() {
                hex_bar_at(seg_G);
                hex_bar_at(seg_E);
                hex_bar_at(seg_C);
                hex_bar_at(seg_D);
            }
            // DP appendage: hull from C to DP so it joins the body
            hull() {
                hex_bar_at(seg_C);
                translate(dp_pos)
                    circle(d = dp_d, $fn = 48);
            }
        }
    }
}


// =============================================================================
// 3D MODULES
// =============================================================================

module hex_pocket_3d(seg, h) {
    translate([seg[0], seg[1], 0])
        rotate([0, 0, seg[2]])
            linear_extrude(height = h)
                hex_bar_2d(seg_length, seg_width, seg_chamfer);
}

module dp_pocket_3d(h) {
    translate([dp_pos[0], dp_pos[1], 0])
        cylinder(d = dp_d, h = h, $fn = 48);
}

module mounting_hole_3d(y, h) {
    translate([0, y, 0])
        cylinder(d = mount_hole_d, h = h, $fn = 48);
}

module baffle_v2() {
    body_t = baffle_thickness - baffle_base_t;

    // === thin base layer (digit silhouette, contains mount holes) ===
    difference() {
        linear_extrude(height = baffle_base_t)
            digit_silhouette();
        translate([0, 0, -0.05]) {
            mounting_hole_3d(mount_hole_y_top, baffle_base_t + 0.1);
            mounting_hole_3d(mount_hole_y_bot, baffle_base_t + 0.1);
        }
    }

    // === body layer (digit silhouette with segment pockets) ===
    translate([0, 0, baffle_base_t]) {
        difference() {
            linear_extrude(height = body_t)
                digit_silhouette();
            translate([0, 0, -0.05]) {
                hex_pocket_3d(seg_A, body_t + 0.1);
                hex_pocket_3d(seg_B, body_t + 0.1);
                hex_pocket_3d(seg_C, body_t + 0.1);
                hex_pocket_3d(seg_D, body_t + 0.1);
                hex_pocket_3d(seg_E, body_t + 0.1);
                hex_pocket_3d(seg_F, body_t + 0.1);
                hex_pocket_3d(seg_G, body_t + 0.1);
                dp_pocket_3d(body_t + 0.1);
                mounting_hole_3d(mount_hole_y_top, body_t + 0.1);
                mounting_hole_3d(mount_hole_y_bot, body_t + 0.1);
            }
        }
    }
}

module diffuser_v2() {
    // Single-layer digit silhouette with mount-hole pass-through.
    difference() {
        linear_extrude(height = diffuser_thickness)
            digit_silhouette();
        translate([0, 0, -0.05]) {
            mounting_hole_3d(mount_hole_y_top, diffuser_thickness + 0.1);
            mounting_hole_3d(mount_hole_y_bot, diffuser_thickness + 0.1);
        }
    }
}

// Push-mount clip — already-expanded "drywall anchor" style. Press straight
// through the diffuser → baffle → PCB stack; barbs compress on the way through
// the mount hole and spring back on the underside of the PCB to retain.
module snap_clip() {
    stem_h = diffuser_thickness + baffle_thickness + pcb_thickness;
    difference() {
        union() {
            // Cap (above the diffuser)
            cylinder(d = clip_cap_d, h = clip_cap_h, $fn = 48);
            // Stem (passes through the stack)
            translate([0, 0, clip_cap_h])
                cylinder(d = clip_stem_d, h = stem_h, $fn = 48);
            // Splayed barb (sits proud on the PCB underside)
            translate([0, 0, clip_cap_h + stem_h])
                cylinder(d1 = clip_barb_max_d,
                         d2 = clip_stem_d * 0.9,
                         h  = clip_barb_h,
                         $fn = 48);
        }
        // Compressibility slits — two crossing rectangular cuts through the
        // barb and a short distance up into the stem so the four resulting
        // fingers can flex inward during insertion.
        for (a = [0, 90]) rotate([0, 0, a])
            translate([-clip_slit_w/2,
                       -clip_barb_max_d,
                       clip_cap_h + stem_h - clip_slit_into_stem])
                cube([clip_slit_w,
                      2 * clip_barb_max_d,
                      clip_barb_h + clip_slit_into_stem + 0.1]);
    }
}


// =============================================================================
// RENDER
// =============================================================================

if (mode == "baffle") {
    baffle_v2();
} else if (mode == "diffuser") {
    diffuser_v2();
} else if (mode == "clip") {
    snap_clip();
} else {
    // preview: assembled stack
    baffle_v2();
    color([1, 1, 1, 0.35])
        translate([0, 0, baffle_thickness + 0.5])
            diffuser_v2();
    // two clips dropped through the mount holes for visual reference
    color([0.4, 0.4, 0.4, 0.9]) {
        translate([0, mount_hole_y_top,
                   baffle_thickness + 0.5 + diffuser_thickness])
            rotate([180, 0, 0])
                snap_clip();
        translate([0, mount_hole_y_bot,
                   baffle_thickness + 0.5 + diffuser_thickness])
            rotate([180, 0, 0])
                snap_clip();
    }
}
