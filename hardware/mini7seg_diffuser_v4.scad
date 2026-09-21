// =============================================================================
// mini7seg_diffuser_v4.scad
// Iteration 4: multi-digit cover. One printable part that spans N adjacent
// mini7seg PCBs as they come off the V-cut panel.
//
// PARAMETERS YOU LIKELY WANT TO CHANGE:
//   digit_count       — how many digits across (1, 4, 6, …)
//   inter_digit_gap   — extra mm between adjacent boards. 0 = boards tight
//                       (V-cut just snapped apart). Bump up if the user has
//                       physically separated the boards in their build.
//
// Geometry inherited from v3:
//   - Digit silhouette outline (figure-8 + DP appendage)
//   - Hex segment + DP pockets cut full-thru (clear LED columns)
//   - Two integral down-pegs per digit, each split by a single full-length
//     slot into two flexing legs that snap below the PCB
//
// New geometry:
//   - N digits laid out along +X, pitch = board_w + inter_digit_gap
//   - A small opaque bridge between each adjacent pair of digits, sitting at
//     the digit waistline (y ~ 0), overlapping into both neighbors so the
//     whole part prints as one piece
// =============================================================================


// ---------- BOARD ----------
board_w        = 20.2;
board_h        = 34.3;
pcb_thickness  = 1.6;

header_zone_top = 4.0;
header_zone_bot = 4.0;

mount_hole_d        = 3.2;
mount_hole_y_top    =  5.5;
mount_hole_y_bot    = -5.5;


// ---------- SEGMENT GEOMETRY ----------
seg_length  = 7.0;
seg_width   = 2.4;
seg_chamfer = 0.9;


// ---------- DIGIT LAYOUT (per-digit, local frame) ----------
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
baffle_thickness   = 4.0;
diffuser_thickness = 1.2;
silhouette_margin  = 1.0;


// ---------- INTEGRAL CLIP / PEG ----------
peg_stem_d         = mount_hole_d - 0.2;
peg_barb_max_d     = 4.5;
peg_barb_h         = 1.5;
peg_barb_tip_d     = peg_stem_d * 0.4;
peg_slit_w         = 0.5;


// ---------- MULTI-DIGIT ----------
digit_count       = 4;     // 1, 4, 5, 6, …
inter_digit_gap   = 0.0;   // mm between adjacent boards (V-cut snapped tight = 0)
bridge_height     = 2.5;   // Y extent of the inter-digit bridge (centered at y=0)
bridge_overlap    = 1.5;   // bridge overlaps this far into each neighbor's silhouette

// X extents of one digit's silhouette AT THE WAIST (y ≈ 0), in its local frame.
// These are the values the bridge anchors to — NOT the overall silhouette
// width (which is bigger because of the DP appendage at the lower-right).
silhouette_right_x_at_waist = 5.0;
silhouette_left_x_at_waist  = -5.0;


// ---------- RENDER MODE ----------
// One of: "baffle", "diffuser", "preview"
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

module digit_silhouette() {
    offset(r = silhouette_margin) {
        union() {
            hull() {
                hex_bar_at(seg_A);
                hex_bar_at(seg_F);
                hex_bar_at(seg_B);
                hex_bar_at(seg_G);
            }
            hull() {
                hex_bar_at(seg_G);
                hex_bar_at(seg_E);
                hex_bar_at(seg_C);
                hex_bar_at(seg_D);
            }
            hull() {
                hex_bar_at(seg_C);
                translate(dp_pos)
                    circle(d = dp_d, $fn = 48);
            }
        }
    }
}


// =============================================================================
// 3D HELPERS (single-digit, local frame)
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

module barb_cone(wide_at_bottom) {
    d_lo = wide_at_bottom ? peg_barb_max_d : peg_barb_tip_d;
    d_hi = wide_at_bottom ? peg_barb_tip_d : peg_barb_max_d;
    cylinder(d1 = d_lo, d2 = d_hi, h = peg_barb_h, $fn = 48);
}

module integral_peg(y) {
    translate([0, y, 0]) {
        difference() {
            union() {
                translate([0, 0, -pcb_thickness])
                    cylinder(d = peg_stem_d, h = pcb_thickness, $fn = 48);
                translate([0, 0, -pcb_thickness - peg_barb_h])
                    barb_cone(false);
            }
            // Single full-length slot through shaft + barb
            translate([-peg_slit_w/2,
                       -peg_barb_max_d,
                       -pcb_thickness - peg_barb_h])
                cube([peg_slit_w,
                      2 * peg_barb_max_d,
                      peg_barb_h + pcb_thickness]);
        }
    }
}


// =============================================================================
// SINGLE-DIGIT PARTS (local frame, centered on origin)
// =============================================================================

module single_digit_baffle() {
    difference() {
        linear_extrude(height = baffle_thickness)
            digit_silhouette();
        translate([0, 0, -0.05]) {
            hex_pocket_3d(seg_A, baffle_thickness + 0.1);
            hex_pocket_3d(seg_B, baffle_thickness + 0.1);
            hex_pocket_3d(seg_C, baffle_thickness + 0.1);
            hex_pocket_3d(seg_D, baffle_thickness + 0.1);
            hex_pocket_3d(seg_E, baffle_thickness + 0.1);
            hex_pocket_3d(seg_F, baffle_thickness + 0.1);
            hex_pocket_3d(seg_G, baffle_thickness + 0.1);
            dp_pocket_3d(baffle_thickness + 0.1);
        }
    }
    integral_peg(mount_hole_y_top);
    integral_peg(mount_hole_y_bot);
}

module single_digit_diffuser() {
    linear_extrude(height = diffuser_thickness)
        digit_silhouette();
}


// =============================================================================
// MULTI-DIGIT ASSEMBLY
// =============================================================================

// Bridge between digit i and digit (i+1). Anchored to the waist X-extent on
// each neighbor (NOT the overall silhouette width — DP appendage is far from
// the waist), so the bridge actually overlaps into the silhouette and fuses
// with it under union().
module inter_digit_bridge(i_left, h) {
    pitch = board_w + inter_digit_gap;
    x_start = i_left * pitch + silhouette_right_x_at_waist - bridge_overlap;
    x_end   = (i_left + 1) * pitch + silhouette_left_x_at_waist + bridge_overlap;
    translate([x_start, -bridge_height/2, 0])
        cube([x_end - x_start, bridge_height, h]);
}

module multi_digit_baffle() {
    pitch = board_w + inter_digit_gap;
    union() {
        for (i = [0 : digit_count - 1])
            translate([i * pitch, 0, 0])
                single_digit_baffle();
        if (digit_count > 1)
            for (i = [0 : digit_count - 2])
                inter_digit_bridge(i, baffle_thickness);
    }
}

// No bridges on the diffuser — those are mechanical, not optical. The N
// silhouettes print as N disjoint pieces in a single STL; the slicer handles
// them as separate parts on the bed.
module multi_digit_diffuser() {
    pitch = board_w + inter_digit_gap;
    for (i = [0 : digit_count - 1])
        translate([i * pitch, 0, 0])
            single_digit_diffuser();
}


// =============================================================================
// RENDER
// =============================================================================

if (mode == "baffle") {
    multi_digit_baffle();
} else if (mode == "diffuser") {
    multi_digit_diffuser();
} else {
    multi_digit_baffle();
    color([1, 1, 1, 0.35])
        translate([0, 0, baffle_thickness])
            multi_digit_diffuser();
}
