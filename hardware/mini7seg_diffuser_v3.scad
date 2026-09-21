// =============================================================================
// mini7seg_diffuser_v3.scad
// Iteration 3: hex pockets all the way through + clips printed as part of the
// baffle's opaque material (no separate clip parts).
//
// Differences from v2:
//   1. Hex segment pockets and the DP pocket now go through the FULL baffle
//      thickness (no solid base under the LEDs). Each tube is a clear column
//      from the PCB up to the baffle's top face — light from each WS2812 is
//      free to leave its tube and hit the diffuser without bleeding sideways.
//   2. Mounting clips are now integral with the baffle. Each mount position
//      grows a "down peg" out of the baffle's silhouette body — extending
//      below the baffle, through the PCB hole, ending in a 4-finger splayed
//      barb that locks against the PCB underside.
//      Diffuser is NOT peg-mounted; it sits on the baffle's top face and is
//      held by friction / glue / a future rim-clip iteration.
//   3. The thin extra "base layer" idea from v2 is gone — the silhouette body
//      is now a single solid extrusion with the pockets carved through it.
//      The mount-hole XY positions are deliberately NOT cut, so they remain
//      solid baffle material out of which the integral pegs grow.
// =============================================================================


// ---------- BOARD ----------
board_w        = 20.2;
board_h        = 34.3;
pcb_thickness  = 1.6;

header_zone_top = 4.0;
header_zone_bot = 4.0;

// Mounting positions on the PCB. NOT subtracted from the baffle — instead the
// integral pegs grow from these positions.
mount_hole_d        = 3.2;
mount_hole_y_top    =  5.5;
mount_hole_y_bot    = -5.5;


// ---------- SEGMENT GEOMETRY ----------
seg_length  = 7.0;
seg_width   = 2.4;
seg_chamfer = 0.9;


// ---------- DIGIT LAYOUT ----------
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
// Stem fits through the 3.2 mm mount hole with a small slip clearance.
peg_stem_d         = mount_hole_d - 0.2;     // 3.0 mm
peg_barb_max_d     = 4.5;                    // splayed barb diameter (must exceed mount_hole_d)
peg_barb_h         = 1.5;                    // barb cone height
peg_barb_tip_d     = peg_stem_d * 0.4;       // narrow end of barb cone
peg_slit_w         = 0.5;                    // compressibility slit width (printable minimum)
peg_slit_into_stem = 1.0;                    // slit extends this far up into the stem


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
// 3D HELPERS
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

// One barb cone (frustum). Plain solid — slot is cut at the peg level so it
// can run continuously through both shaft and barb.
//   wide_at_bottom = true  → cone is wide at z=0, tapers up to a tip
//   wide_at_bottom = false → cone is narrow at z=0, widens up to z=h
module barb_cone(wide_at_bottom) {
    d_lo = wide_at_bottom ? peg_barb_max_d : peg_barb_tip_d;
    d_hi = wide_at_bottom ? peg_barb_tip_d : peg_barb_max_d;
    cylinder(d1 = d_lo, d2 = d_hi, h = peg_barb_h, $fn = 48);
}

// Integral peg at the given Y position. Grows DOWN from the baffle's
// underside, through the PCB hole, ending in a 4-finger... actually no — a
// TWO-LEGGED barb. A single 0.5 mm slot is cut all the way through the shaft
// and the barb, splitting the peg into two half-cylinders that flex toward
// each other when squeezed through the mount hole. The shaft itself
// contributes most of the bending compliance; the two half-cone barb
// segments flare back out below the PCB to lock.
module integral_peg(y) {
    translate([0, y, 0]) {
        difference() {
            union() {
                // stem through PCB hole
                translate([0, 0, -pcb_thickness])
                    cylinder(d = peg_stem_d, h = pcb_thickness, $fn = 48);
                // splayed barb at the tip
                translate([0, 0, -pcb_thickness - peg_barb_h])
                    barb_cone(false);
            }
            // Single full-length slot. Cuts straight through both halves of
            // the shaft and barb, from the barb's tip up to the baffle's
            // underside. The two resulting legs flex toward each other on
            // insertion and spring back below the PCB.
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
// PARTS
// =============================================================================

module baffle_v3() {
    // Single solid extrusion of the digit silhouette, with hex pockets and DP
    // cut FULL DEPTH so each LED has a clear column to the diffuser. Mount-hole
    // positions are intentionally not cut — they remain solid material from
    // which the integral pegs grow.
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

    // Integral pegs at both mount positions — printed as part of this same part.
    integral_peg(mount_hole_y_top);
    integral_peg(mount_hole_y_bot);
}

module diffuser_v3() {
    // Plain digit-silhouette lid. No mount holes — nothing pokes through it
    // from the baffle. Sits on the baffle's top face by friction (or future
    // attachment scheme: rim clip, glue dot, etc.).
    linear_extrude(height = diffuser_thickness)
        digit_silhouette();
}


// =============================================================================
// RENDER
// =============================================================================

if (mode == "baffle") {
    baffle_v3();
} else if (mode == "diffuser") {
    diffuser_v3();
} else {
    // preview: assembled stack — baffle (with integral pegs visible above
    // and below) + translucent diffuser sitting on top of the baffle.
    baffle_v3();
    color([1, 1, 1, 0.35])
        translate([0, 0, baffle_thickness])
            diffuser_v3();
}
