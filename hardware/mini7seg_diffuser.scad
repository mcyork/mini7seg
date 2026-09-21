// =============================================================================
// mini7seg_diffuser.scad
// Parametric LED diffuser/baffle overlay for the mcyork/mini7seg PCB.
//
// PURPOSE
//   The mini7seg PCB places one WS2812B-2020 LED behind each of seven hex-bar
//   segments + a round DP. To make it look like a traditional 7-segment digit,
//   we want two stacked layers above the board:
//
//     Layer 2  ┌──────────────────────────────┐  diffuser (translucent)
//              │   light-spreading flat cap   │
//     Layer 1  ├──┬──┬──┬──┬──┬──┬──┬──┬──┬──┤  baffle (opaque)
//              │  │A │B │C │D │E │F │G │·│  │   hex tubes that contain each
//              │  └──┴──┴──┴──┴──┴──┴──┴─┴──┘   LED's light, no neighbor bleed
//     PCB      [   board with 8 LEDs                                  ]
//
//   Print baffle in opaque filament (black/dark grey).
//   Print diffuser in translucent / natural / white-translucent filament,
//   ~0.8–1.2 mm thick, low infill, "vase mode" or 100% infill both work.
//
// LAYOUT REFERENCE
//   See ../images/pcb-design.png. Outer board 20.2 × 34.3 mm.
//   Segments are elongated hexagons. Two through-holes (C1, C2). 3-pin
//   headers H1 (top) and H2 (bottom) for daisy-chain. DP near bottom-right.
//
// DISCLAIMER
//   Segment XY positions and the mounting-hole Y values below are derived
//   from the PCB design image, not from the actual gerbers. Print baffle v1,
//   set it on the board, and tweak the seg_*_pos / mount_hole_y_* / dp_pos
//   numbers if anything is off. All offsets in millimeters, board-frame
//   origin = geometric center of the PCB, +X = right, +Y = up.
// =============================================================================


// ---------- BOARD ----------
board_w        = 20.2;     // PCB width  (X)
board_h        = 34.3;     // PCB height (Y)
header_zone_top = 4.0;     // clearance for H1 connector at top edge
header_zone_bot = 4.0;     // clearance for H2 connector at bottom edge

// Mounting holes (C1, C2 on the silk). Diameters from typical M3 clearance.
mount_hole_d        = 3.2;
mount_hole_y_top    =  5.5;   // C1 — adjust after measuring
mount_hole_y_bot    = -5.5;   // C2 — adjust after measuring


// ---------- SEGMENT GEOMETRY (one hex-bar) ----------
// Six-sided elongated hexagon: a rectangle with both ends pointed.
seg_length  = 7.0;     // long axis (tip to tip)
seg_width   = 2.4;     // short axis (across the bar)
seg_chamfer = 0.9;     // length of the pointed end region


// ---------- DIGIT LAYOUT ----------
// [x_center, y_center, rotation_deg]. Rotation 0 = horizontal bar (long axis on X).
seg_A = [ 0,    11.0,   0];   // top
seg_B = [ 4.5,  6.0,   90];   // top-right
seg_C = [ 4.5, -6.0,   90];   // bottom-right
seg_D = [ 0,   -11.0,   0];   // bottom
seg_E = [-4.5, -6.0,   90];   // bottom-left
seg_F = [-4.5,  6.0,   90];   // top-left
seg_G = [ 0,    0.0,    0];   // middle

// Decimal point — round LED at lower-right
dp_pos = [ 7.5, -10.0];
dp_d   = 2.0;


// ---------- BAFFLE ----------
baffle_thickness = 4.0;    // tube height; tweak per LED dome height + headroom
wall_min         = 0.8;    // visual reference; not enforced — set seg dims to respect this


// ---------- DIFFUSER ----------
diffuser_thickness = 1.2;
diffuser_overhang  = 0.5;  // extends past PCB edges by this much


// ---------- RENDER MODE ----------
// One of: "baffle", "diffuser", "preview"
mode = "preview";


// =============================================================================
// MODULES
// =============================================================================

// Elongated hex (6 vertices), centered at origin, long axis on X.
module hex_bar(length, width, chamfer) {
    polygon(points = [
        [-length/2 + chamfer, -width/2],
        [ length/2 - chamfer, -width/2],
        [ length/2,            0      ],
        [ length/2 - chamfer,  width/2],
        [-length/2 + chamfer,  width/2],
        [-length/2,            0      ],
    ]);
}

// Place a hex pocket at the given segment position
module hex_pocket(seg, h) {
    translate([seg[0], seg[1], 0])
        rotate([0, 0, seg[2]])
            linear_extrude(height = h)
                hex_bar(seg_length, seg_width, seg_chamfer);
}

module dp_pocket(h) {
    translate([dp_pos[0], dp_pos[1], 0])
        cylinder(d = dp_d, h = h, $fn = 48);
}

module mounting_hole(y, h) {
    translate([0, y, 0])
        cylinder(d = mount_hole_d, h = h, $fn = 48);
}

module header_cutout_top(h) {
    translate([-board_w/2 - 0.1, board_h/2 - header_zone_top, 0])
        cube([board_w + 0.2, header_zone_top + 0.1, h]);
}

module header_cutout_bot(h) {
    translate([-board_w/2 - 0.1, -board_h/2 - 0.1, 0])
        cube([board_w + 0.2, header_zone_bot + 0.1, h]);
}

module baffle() {
    difference() {
        // solid plate the size of the PCB
        translate([-board_w/2, -board_h/2, 0])
            cube([board_w, board_h, baffle_thickness]);

        // subtract segment pockets (slight Z over-cut for clean rendering)
        translate([0, 0, -0.05]) {
            hex_pocket(seg_A, baffle_thickness + 0.1);
            hex_pocket(seg_B, baffle_thickness + 0.1);
            hex_pocket(seg_C, baffle_thickness + 0.1);
            hex_pocket(seg_D, baffle_thickness + 0.1);
            hex_pocket(seg_E, baffle_thickness + 0.1);
            hex_pocket(seg_F, baffle_thickness + 0.1);
            hex_pocket(seg_G, baffle_thickness + 0.1);
            dp_pocket(baffle_thickness + 0.1);

            mounting_hole(mount_hole_y_top, baffle_thickness + 0.1);
            mounting_hole(mount_hole_y_bot, baffle_thickness + 0.1);

            header_cutout_top(baffle_thickness + 0.1);
            header_cutout_bot(baffle_thickness + 0.1);
        }
    }
}

module diffuser() {
    // Same outer profile as the baffle (so it stacks cleanly), with the same
    // mount-hole + header-cutout pattern punched through. No segment pockets —
    // this layer is a continuous sheet that lets light through from below.
    difference() {
        translate([-board_w/2, -board_h/2, 0])
            cube([board_w, board_h, diffuser_thickness]);

        translate([0, 0, -0.05]) {
            mounting_hole(mount_hole_y_top, diffuser_thickness + 0.1);
            mounting_hole(mount_hole_y_bot, diffuser_thickness + 0.1);
            header_cutout_top(diffuser_thickness + 0.1);
            header_cutout_bot(diffuser_thickness + 0.1);
        }
    }
}


// =============================================================================
// RENDER
// =============================================================================

if (mode == "baffle") {
    baffle();
} else if (mode == "diffuser") {
    diffuser();
} else {
    // preview: baffle + translucent diffuser floating above so you can see
    // the tube structure
    baffle();
    color([1, 1, 1, 0.35])
        translate([0, 0, baffle_thickness + 0.5])
            diffuser();
}
