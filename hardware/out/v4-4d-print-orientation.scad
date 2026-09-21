// Print orientation for the 4-digit v4 cover: the assembly is baffle-then-
// diffuser going up, but it prints FLIPPED so the clear viewer face lies on the
// bed (smooth optical surface, and the snap pegs point up instead of trying to
// print on their barb tips). Both volumes take the same transform, so they stay
// in register when merged into one two-colour object.
part   = "clear";
bt     = 4.0;      // baffle_thickness — where the diffuser sits in the assembly
lift   = 5.2;      // bt + diffuser_thickness: puts the flipped part on z = 0
cx     = 31.70;    // part centre in X
bx     = 125; by = 110;   // MK4S bed centre
baffle = "BAF"; diff = "DIF";
if (part == "clear")
  translate([bx-cx, by, lift]) rotate([180,0,0]) translate([0,0,bt]) import(diff);
else
  translate([bx-cx, by, lift]) rotate([180,0,0]) import(baffle);
