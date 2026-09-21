// =============================================================================
// mini7seg_diffuser_v5.scad
//
// Iteration 5. The whole point of this version: EVERY number below that
// describes the board is READ OFF THE PCB, not guessed.
//
// Source of truth:
//   EasyEDA Pro project  "7-seg-string"
//   archive              ProPrj_7-seg-string_2026-01-20-00-00-08.epro
//   board                PCB/d97f67a54bbb46e88dcb99f7e0514d6e.epcb
//   records used         COMPONENT + ATTR "Designator"  -> LED centroids
//                        PAD (layer 12, GND)            -> mount holes
//                        POLY layer 11 ["R",0,0,800,1350] -> board outline
//   units in that file   mil. 1 mil = 0.0254 mm. Frame is board-centre,
//                        +X right, +Y up (board centre lands at
//                        (0.005, 0.448) mm in this frame — under half a mm,
//                        so we treat this frame AS board centre).
//
// WHY v4 DID NOT FIT (measured, not theorised):
//   v4 assumed the digit was centred on x = 0 with a +/-4.5 mm half-span.
//   The real digit is centred on x = -1.778 mm with a +/-5.207 mm half-span.
//   That put the left-hand baffle wall 2.485 mm inboard of LEDE / LEDF —
//   which is why the part sat ON the left LEDs instead of over them.
//   v4 also assumed a 3.2 mm mount hole and cut a 3.0 mm barbed peg for it.
//   The real drill is 2.50 mm, at 10.414 mm spacing (not 11.0). The pegs
//   could never have entered the holes.
//
// WHAT CHANGED FROM v4:
//   - segment + DP positions derived from LED centroids
//   - barbed split snap peg  ->  plain straight post, heat-staked with a
//     soldering iron into a rivet on the underside of the board
//   - seg_width 2.4 -> 3.2 (LED body is 2.0 mm square; 0.6 mm clear each side)
//   - dp_d 2.0 -> 3.408, derived from the LED's diagonal
//   - diffuser_thickness 1.2 -> 1.8
// =============================================================================


// ---------- BOARD (from POLY layer 11) ----------
board_w        = 20.32;    // 800 mil
board_h        = 34.29;    // 1350 mil
pcb_thickness  = 1.6;


// ---------- MOUNT HOLES (from PAD e298 / e299, layer 12, net GND) ----------
// hole ROUND 98.4252 mil = 2.500 mm ; pad ELLIPSE 137.7953 mil = 3.500 mm
mount_hole_d   = 2.50;
mount_pad_d    = 3.50;
mount_top      = [-1.778,  5.207];
mount_bot      = [-1.905, -5.207];


// ---------- LED CENTROIDS (from COMPONENT + ATTR Designator) ----------
// These are the ONLY placement facts. Everything else is derived from them.
led_A  = [-1.778,  10.414];
led_B  = [ 3.429,   4.888];
led_C  = [ 3.429,  -5.334];
led_D  = [-1.716, -10.668];
led_E  = [-6.985,  -5.396];
led_F  = [-6.985,   4.826];
led_G  = [-1.778,  -0.254];
led_DP = [ 7.493, -10.414];

led_body = 2.0;            // WS2812 2020 package, 2.0 x 2.0 mm


// ---------- DERIVED DIGIT GRID ----------
// Column / row lines the segments sit on. Cross-axis position of each segment
// is its own LED's coordinate (guarantees that LED clears). Along-axis position
// is the geometric cell centre (keeps the figure-8 looking square).
x_left   = led_F[0];                       // -6.985  (E / F column)
x_right  = led_B[0];                       //  3.429  (B / C column)
x_mid    = led_A[0];                       // -1.778  (A / G / D column)
y_top    = led_A[1];                       //  10.414
y_mid    = led_G[1];                       //  -0.254
y_bot    = led_D[1];                       // -10.668


// ---------- SEGMENT GEOMETRY ----------
// seg_width and dp_d are DERIVED from led_body on purpose. v4 died of
// hand-computed numbers drifting away from the thing they were computed from;
// if the LED package ever changes, edit led_body and everything follows.
seg_clearance = 0.6;                              // flat-to-flat, each side
seg_width     = led_body + 2 * seg_clearance;     // 3.2
seg_gap       = 0.5;       // gap between the end of one segment and the next
seg_chamfer   = 0.9;

// Lengths fall out of the grid so the corners close by construction.
len_h       = (x_right - x_left) - seg_width - 2 * seg_gap;   // A, G, D
len_v_up    = (y_top   - y_mid)  - seg_width - 2 * seg_gap;   // B, F
len_v_dn    = (y_mid   - y_bot)  - seg_width - 2 * seg_gap;   // C, E

// [x, y, rotation, length]
seg_A = [x_mid,   y_top,                 0, len_h   ];
seg_B = [x_right, (y_top + y_mid) / 2,  90, len_v_up];
seg_C = [x_right, (y_mid + y_bot) / 2,  90, len_v_dn];
seg_D = [x_mid,   y_bot,                 0, len_h   ];
seg_E = [x_left,  (y_mid + y_bot) / 2,  90, len_v_dn];
seg_F = [x_left,  (y_top + y_mid) / 2,  90, len_v_up];
seg_G = [x_mid,   y_mid,                 0, len_h   ];

segments = [seg_A, seg_B, seg_C, seg_D, seg_E, seg_F, seg_G];

dp_pos = led_DP;
// v4 used 2.0 — exactly the LED body size, so it covered nothing at all.
// A circle over a square is bound by the square's CORNER (1.414 mm from
// centre), not its flat, so this is derived from the diagonal.
dp_corner_clearance = 0.29;
dp_d = led_body * sqrt(2) + 2 * dp_corner_clearance;   // 3.408
// This is the tightest feature on the part and it cannot simply be opened up:
// LEDDP sits only 2.667 mm in from the board edge, so anything over
// dp_d = 3.334 puts the silhouette past the edge. At 3.408 it overhangs by
// 0.037 mm — a sixth of a layer line, and the neighbouring digit is still
// 1.35 mm away, so the overhang is accepted in exchange for the clearance.


// ---------- LAYER STACK ----------
baffle_thickness   = 4.0;
diffuser_thickness = 1.8;  // was 1.2
silhouette_margin  = 1.0;


// ---------- POST (heat-staked rivet, replaces the v4 barbed snap peg) ----------
// Straight cylinder, slip fit through the 2.50 mm hole, standing proud of the
// underside of the board by post_stake. That proud length is the material a
// soldering iron spreads into a rivet head over the 3.50 mm pad.
//   Volume check, counting the chamfered tip and the plastic that first has
//   to fill the 0.125 mm annulus around the post inside the hole:
//     proud material   5.863 mm^3
//     annulus fill    -1.492 mm^3
//     left for a head  4.371 mm^3  over the 3.50 mm pad = 0.454 mm. Enough.
post_clearance = 0.25;                          // total diametral clearance
post_d         = mount_hole_d - post_clearance; // 2.25
post_stake     = 1.6;                           // proud below the board
post_lead      = 0.4;                           // tip chamfer, starts the hole


// ---------- MULTI-DIGIT ----------
digit_count     = 4;
inter_digit_gap = 0.0;     // V-cut snapped tight
bridge_height   = 2.5;
// The bridge runs from the CENTRE of one digit to the centre of the next, so
// it is buried deep inside both silhouettes and cannot fail to weld.
//
// It used to anchor on the silhouette's X extent computed as
// x_right + seg_width/2 + margin. That measures the B/C segment column, but
// digit_silhouette() hulls the top and bottom cells SEPARATELY, so at the
// waist the union pinches into a 45-degree notch reaching only 3.443 — not
// 6.029. The bridge therefore started 1.086 mm outside the part it was
// supposed to join, and touched only at two 0.164 mm slivers: a 1.3 mm^2 weld
// where 10 mm^2 was intended. It showed up as genus 38 on the 4-digit baffle
// where 32 is correct — two extra handles per bridge, one per sliver.
// Anchoring on the centreline removes the need to know the outline at all.


// ---------- RENDER MODE ----------
// "baffle" | "diffuser" | "preview"
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
            hex_bar_2d(seg[3], seg_width, seg_chamfer);
}

module digit_silhouette() {
    offset(r = silhouette_margin) {
        union() {
            hull() { hex_bar_at(seg_A); hex_bar_at(seg_F);
                     hex_bar_at(seg_B); hex_bar_at(seg_G); }
            hull() { hex_bar_at(seg_G); hex_bar_at(seg_E);
                     hex_bar_at(seg_C); hex_bar_at(seg_D); }
            hull() { hex_bar_at(seg_C);
                     translate(dp_pos) circle(d = dp_d, $fn = 64); }
        }
    }
}


// =============================================================================
// 3D HELPERS (single digit, local frame)
// =============================================================================

module hex_pocket_3d(seg, h) {
    translate([seg[0], seg[1], 0])
        rotate([0, 0, seg[2]])
            linear_extrude(height = h)
                hex_bar_2d(seg[3], seg_width, seg_chamfer);
}

module dp_pocket_3d(h) {
    translate([dp_pos[0], dp_pos[1], 0])
        cylinder(d = dp_d, h = h, $fn = 64);
}

// Straight post: full diameter through the board, chamfered tip so it finds
// the hole. No barb, no slit — the rivet is formed after assembly with heat.
module heat_stake_post(xy) {
    total = pcb_thickness + post_stake;
    translate([xy[0], xy[1], -total]) {
        // chamfered tip, so the post finds the hole instead of catching its rim
        cylinder(d1 = post_d - 2 * post_lead, d2 = post_d, h = post_lead, $fn = 48);
        // Straight shank up into the baffle. The extra 0.01 is a deliberate
        // overlap — a face exactly coplanar with the baffle underside is a
        // zero-thickness join waiting to go non-manifold on the next edit.
        translate([0, 0, post_lead])
            cylinder(d = post_d, h = total - post_lead + 0.01, $fn = 48);
    }
}


// =============================================================================
// SINGLE-DIGIT PARTS
// =============================================================================

module single_digit_solid() {
    linear_extrude(height = baffle_thickness)
        digit_silhouette();
}

module single_digit_pockets() {
    translate([0, 0, -0.05]) {
        for (s = segments) hex_pocket_3d(s, baffle_thickness + 0.1);
        dp_pocket_3d(baffle_thickness + 0.1);
    }
}

module single_digit_posts() {
    heat_stake_post(mount_top);
    heat_stake_post(mount_bot);
}

module single_digit_baffle() {
    difference() { single_digit_solid(); single_digit_pockets(); }
    single_digit_posts();
}

module single_digit_diffuser() {
    linear_extrude(height = diffuser_thickness)
        digit_silhouette();
}


// =============================================================================
// MULTI-DIGIT ASSEMBLY
// =============================================================================

module inter_digit_bridge(i_left, h) {
    pitch   = board_w + inter_digit_gap;
    x_start = i_left * pitch + x_mid;
    x_end   = (i_left + 1) * pitch + x_mid;
    translate([x_start, y_mid - bridge_height/2, 0])
        cube([x_end - x_start, bridge_height, h]);
}

// Pockets are subtracted AFTER the bridges are unioned in. That ordering is
// what lets the bridge run right through the middle of a digit without any
// risk of it filling a segment well — the well is cut last and always wins.
// Doing it per-digit first (as v4 did) is what forced the bridge to tiptoe
// around the outline, and that is where the bad anchor came from.
module multi_digit_baffle() {
    pitch = board_w + inter_digit_gap;
    difference() {
        union() {
            for (i = [0 : digit_count - 1])
                translate([i * pitch, 0, 0]) single_digit_solid();
            if (digit_count > 1)
                for (i = [0 : digit_count - 2])
                    inter_digit_bridge(i, baffle_thickness);
        }
        for (i = [0 : digit_count - 1])
            translate([i * pitch, 0, 0]) single_digit_pockets();
    }
    for (i = [0 : digit_count - 1])
        translate([i * pitch, 0, 0]) single_digit_posts();
}

// No bridges on the diffuser — those are mechanical, not optical.
module multi_digit_diffuser() {
    pitch = board_w + inter_digit_gap;
    for (i = [0 : digit_count - 1])
        translate([i * pitch, 0, 0]) single_digit_diffuser();
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
