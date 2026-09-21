#!/usr/bin/env bun
// Build the mini7seg cover: OpenSCAD -> STL -> flipped print orientation ->
// two-colour 3MF ready for Curie (MK4S + MMU3).
//
//   bun Build.ts                 # 4 digits, the usual
//   bun Build.ts --digits 1      # single digit test piece
//   bun Build.ts --no-3mf        # STLs only
//
// WHY THE PART PRINTS UPSIDE DOWN
//   In the assembly the stack is, going up: posts (below the board), baffle,
//   diffuser. Printed as-assembled the posts would point down into the bed.
//   So everything is flipped: the clear viewing face goes on the bed (which
//   also gives it a smooth optical surface off the sheet) and the posts rise
//   as free-standing vertical cylinders that need no support.
//   Print order is therefore CLEAR first, then BLACK. That is the opposite of
//   how the finished part reads in the hand, which is a good way to get
//   confused — the assembly is black-on-the-board, clear-to-the-eye.

import { $ } from "bun";
import { basename, join } from "node:path";
import { mkdir } from "node:fs/promises";

const HERE = import.meta.dir;
// Two parts share this builder: the standalone cover, and the enclosure. The
// enclosure is already modelled in print orientation (window on the bed,
// building up) so it needs no flip — the cover does.
const PART = (() => {
  const i = Bun.argv.indexOf("--part");
  return i >= 0 && Bun.argv[i + 1] ? Bun.argv[i + 1] : "cover";
})();
const IS_ENCLOSURE = PART === "enclosure";
const SCAD = join(HERE, IS_ENCLOSURE ? "mini7seg_enclosure_v2.scad" : "mini7seg_diffuser_v5.scad");
const OUT = join(HERE, "out");

const args = process.argv.slice(2);
const flag = (n: string) => args.includes(n);
const val = (n: string, d: string) => {
  const i = args.indexOf(n);
  return i >= 0 && args[i + 1] ? args[i + 1] : d;
};

const digits = Number(val("--digits", "4"));
const EXTRUDER_CLEAR = Number(val("--clear-tool", "3"));
const EXTRUDER_BLACK = Number(val("--black-tool", "2"));
const BED: [number, number] = [250, 210]; // MK4S usable, minus a skirt margin

// Assembly-frame constants — must match the .scad
const BAFFLE_T = 4.0;
const DIFFUSER_T = 1.8;

await mkdir(OUT, { recursive: true });
const tag = IS_ENCLOSURE ? "encv2" : `v5-${digits}d`;

// ---------------------------------------------------------------- STL parsing

type Mesh = { verts: Float64Array; tris: Int32Array };

/** Welding vertex accumulator — the 3MF should not carry 3x the vertices it needs. */
function accumulator() {
  const verts: number[] = [];
  const tris: number[] = [];
  const key = new Map<string, number>();
  return {
    push(x: number, y: number, z: number) {
      const k = `${x.toFixed(5)},${y.toFixed(5)},${z.toFixed(5)}`;
      let i = key.get(k);
      if (i === undefined) {
        i = verts.length / 3;
        key.set(k, i);
        verts.push(x, y, z);
      }
      tris.push(i);
    },
    done: (): Mesh => ({
      verts: Float64Array.from(verts),
      tris: Int32Array.from(tris),
    }),
  };
}

// OpenSCAD emits ASCII STL; other tools emit binary. Accept either — sniffing
// the "solid" header alone is not enough, since some binary writers start their
// 80-byte comment with that word. Cross-check against the declared facet count.
function parseStl(buf: ArrayBuffer): Mesh {
  const looksBinary =
    buf.byteLength >= 84 &&
    84 + new DataView(buf).getUint32(80, true) * 50 === buf.byteLength;
  return looksBinary ? parseBinaryStl(buf) : parseAsciiStl(buf);
}

function parseBinaryStl(buf: ArrayBuffer): Mesh {
  const dv = new DataView(buf);
  const n = dv.getUint32(80, true);
  const acc = accumulator();
  for (let t = 0; t < n; t++) {
    const o = 84 + t * 50 + 12; // skip the normal
    for (let v = 0; v < 3; v++)
      acc.push(
        dv.getFloat32(o + v * 12, true),
        dv.getFloat32(o + v * 12 + 4, true),
        dv.getFloat32(o + v * 12 + 8, true),
      );
  }
  return acc.done();
}

function parseAsciiStl(buf: ArrayBuffer): Mesh {
  const text = new TextDecoder().decode(buf);
  const acc = accumulator();
  const re = /vertex\s+(\S+)\s+(\S+)\s+(\S+)/g;
  let m: RegExpExecArray | null;
  while ((m = re.exec(text)) !== null)
    acc.push(Number(m[1]), Number(m[2]), Number(m[3]));
  return acc.done();
}

/** rotate 180 deg about X (y,z negate), then translate */
function flipAndMove(m: Mesh, dx: number, dy: number, dz: number): Mesh {
  const v = new Float64Array(m.verts.length);
  for (let i = 0; i < m.verts.length; i += 3) {
    v[i] = m.verts[i] + dx;
    v[i + 1] = -m.verts[i + 1] + dy;
    v[i + 2] = -m.verts[i + 2] + dz;
  }
  // mirroring two axes preserves handedness, so winding is still correct
  return { verts: v, tris: m.tris };
}

function bounds(m: Mesh) {
  const lo = [Infinity, Infinity, Infinity];
  const hi = [-Infinity, -Infinity, -Infinity];
  for (let i = 0; i < m.verts.length; i += 3)
    for (let k = 0; k < 3; k++) {
      lo[k] = Math.min(lo[k], m.verts[i + k]);
      hi[k] = Math.max(hi[k], m.verts[i + k]);
    }
  return { lo, hi };
}

function writeBinaryStl(path: string, m: Mesh) {
  const n = m.tris.length / 3;
  const buf = new ArrayBuffer(84 + n * 50);
  const dv = new DataView(buf);
  dv.setUint32(80, n, true);
  for (let t = 0; t < n; t++) {
    const o = 84 + t * 50 + 12;
    for (let v = 0; v < 3; v++) {
      const vi = m.tris[t * 3 + v] * 3;
      dv.setFloat32(o + v * 12, m.verts[vi], true);
      dv.setFloat32(o + v * 12 + 4, m.verts[vi + 1], true);
      dv.setFloat32(o + v * 12 + 8, m.verts[vi + 2], true);
    }
  }
  return Bun.write(path, buf);
}

// ---------------------------------------------------------------- 3MF writing

function modelXml(vols: { mesh: Mesh }[]) {
  const out: string[] = [
    `<?xml version="1.0" encoding="UTF-8"?>`,
    `<model unit="millimeter" xml:lang="en-US" xmlns="http://schemas.microsoft.com/3dmanufacturing/core/2015/02">`,
    ` <resources>`,
    `  <object id="1" type="model">`,
    `   <mesh>`,
    `    <vertices>`,
  ];
  let base = 0;
  const ranges: [number, number][] = [];
  for (const { mesh } of vols)
    for (let i = 0; i < mesh.verts.length; i += 3)
      out.push(
        `     <vertex x="${mesh.verts[i].toFixed(4)}" y="${mesh.verts[i + 1].toFixed(4)}" z="${mesh.verts[i + 2].toFixed(4)}"/>`,
      );
  out.push(`    </vertices>`, `    <triangles>`);
  let tri = 0;
  for (const { mesh } of vols) {
    const first = tri;
    for (let i = 0; i < mesh.tris.length; i += 3) {
      out.push(
        `     <triangle v1="${mesh.tris[i] + base}" v2="${mesh.tris[i + 1] + base}" v3="${mesh.tris[i + 2] + base}"/>`,
      );
      tri++;
    }
    ranges.push([first, tri - 1]);
    base += mesh.verts.length / 3;
  }
  out.push(
    `    </triangles>`,
    `   </mesh>`,
    `  </object>`,
    ` </resources>`,
    ` <build><item objectid="1" transform="1 0 0 0 1 0 0 0 1 0 0 0"/></build>`,
    `</model>`,
  );
  return { xml: out.join("\n"), ranges };
}

function configXml(
  ranges: [number, number][],
  names: string[],
  tools: number[],
  objName: string,
) {
  const v = ranges
    .map(
      ([a, b], i) =>
        `  <volume firstid="${a}" lastid="${b}">\n` +
        `   <metadata type="volume" key="name" value="${names[i]}"/>\n` +
        `   <metadata type="volume" key="volume_type" value="ModelPart"/>\n` +
        `   <metadata type="volume" key="extruder" value="${tools[i]}"/>\n` +
        `   <mesh edges_fixed="0" degenerate_facets="0" facets_removed="0" facets_reversed="0" backwards_edges="0"/>\n` +
        `  </volume>`,
    )
    .join("\n");
  return (
    `<?xml version="1.0" encoding="UTF-8"?>\n<config>\n` +
    ` <object id="1" instances_count="1">\n` +
    `  <metadata type="object" key="name" value="${objName}"/>\n${v}\n` +
    ` </object>\n</config>\n`
  );
}

async function write3mf(path: string, files: Record<string, string>) {
  const dir = join(OUT, ".3mf-stage");
  await $`rm -rf ${dir}`.quiet().nothrow();
  for (const [name, body] of Object.entries(files)) {
    const p = join(dir, name);
    await mkdir(join(p, ".."), { recursive: true });
    await Bun.write(p, body);
  }
  await $`rm -f ${path}`.quiet().nothrow();
  await $`cd ${dir} && zip -r -X -q ${path} .`.quiet();
  await $`rm -rf ${dir}`.quiet().nothrow();
}

// ---------------------------------------------------------------- render

async function scad(mode: string, out: string) {
  const r = IS_ENCLOSURE
    ? await $`openscad -o ${out} -D ${`mode="${mode}"`} ${SCAD}`.quiet().nothrow()
    : await $`openscad -o ${out} -D ${`mode="${mode}"`} -D ${`digit_count=${digits}`} ${SCAD}`
      .quiet()
      .nothrow();
  if (r.exitCode !== 0) {
    console.error(r.stderr.toString().split("\n").slice(-8).join("\n"));
    throw new Error(`openscad failed for mode=${mode}`);
  }
  return parseStl(await Bun.file(out).arrayBuffer());
}

const baffleRaw = await scad(IS_ENCLOSURE ? "black" : "baffle", join(OUT, `${tag}-baffle.stl`));
const diffRaw = await scad(IS_ENCLOSURE ? "window" : "diffuser", join(OUT, `${tag}-diffuser.stl`));

// Put each volume at its ASSEMBLY height first, then flip both by the same
// transform so they stay in register.
//   The .scad renders mode="diffuser" sitting on z=0, not at its assembly
//   height — only the "preview" branch applies the +baffle_thickness lift. So
//   the diffuser has to be raised here or the two volumes interpenetrate
//   instead of stacking. That is a silent, print-ruining failure: the slicer
//   is perfectly happy to slice two overlapping volumes.
// Both parts are now authored in v5's frame (+Z = viewer), so both take the
// SAME flip. The enclosure briefly had its own upside-down frame and a
// keep()-instead-of-flip special case; that is what mirrored the decimal
// points. One frame, one transform, no special case.
const lift = BAFFLE_T + DIFFUSER_T;
// Both parts share v5's frame, but they EXPORT their clear volume differently:
// v5's mode="diffuser" draws it at the origin rather than at its assembly
// height, so it needs raising by BAFFLE_T first; the enclosure's mode="window"
// is already at assembly height. Same frame, different export convention — and
// the seam check below is what turns getting this wrong into an error instead
// of a 45-minute misprint.
const clearLift = IS_ENCLOSURE ? lift : lift - BAFFLE_T;
let black = flipAndMove(baffleRaw, 0, 0, lift);
let clear = flipAndMove(diffRaw, 0, 0, clearLift);

const all = { verts: Float64Array.from([...black.verts, ...clear.verts]), tris: black.tris };
const b = bounds(all);
const dx = BED[0] / 2 - (b.lo[0] + b.hi[0]) / 2;
const dy = BED[1] / 2 - (b.lo[1] + b.hi[1]) / 2;
const dz = -b.lo[2];
const move = (m: Mesh): Mesh => {
  const v = new Float64Array(m.verts.length);
  for (let i = 0; i < m.verts.length; i += 3) {
    v[i] = m.verts[i] + dx;
    v[i + 1] = m.verts[i + 1] + dy;
    v[i + 2] = m.verts[i + 2] + dz;
  }
  return { verts: v, tris: m.tris };
};
black = move(black);
clear = move(clear);

await writeBinaryStl(join(OUT, `${tag}-black.stl`), black);
await writeBinaryStl(join(OUT, `${tag}-clear.stl`), clear);

const fb = bounds(black), fc = bounds(clear);
console.log(`${tag}  ${digits} digit${digits > 1 ? "s" : ""}`);
console.log(
  `  footprint  ${(Math.max(fb.hi[0], fc.hi[0]) - Math.min(fb.lo[0], fc.lo[0])).toFixed(2)} x ` +
    `${(Math.max(fb.hi[1], fc.hi[1]) - Math.min(fb.lo[1], fc.lo[1])).toFixed(2)} mm`,
);
console.log(`  clear      z ${fc.lo[2].toFixed(2)} .. ${fc.hi[2].toFixed(2)}   tool ${EXTRUDER_CLEAR}  (on the bed, prints first)`);
console.log(`  black      z ${fb.lo[2].toFixed(2)} .. ${fb.hi[2].toFixed(2)}   tool ${EXTRUDER_BLACK}  (posts are the tall bit)`);

// The two volumes must meet on one plane: touching, not overlapping, no gap.
// Overlap slices into a mess and a gap delaminates, and neither is visible in
// the numbers above unless you go looking.
const seam = fc.hi[2] - fb.lo[2];
if (Math.abs(seam) > 1e-6) {
  console.error(`  FAIL  clear top and black bottom differ by ${seam.toFixed(4)} mm — volumes are not in register`);
  process.exit(1);
}
console.log(`  seam       z ${fb.lo[2].toFixed(2)}  flush, no overlap`);
if (fc.lo[2] !== 0) {
  console.error(`  FAIL  part does not sit on the bed (clear starts at ${fc.lo[2]})`);
  process.exit(1);
}

// The part is a clean layer-wise split — clear below the seam, black above,
// exactly ONE tool change in the whole print. That does not need the MMU at
// all: a single-extruder colour change at the seam does the same job with no
// wipe tower and no purge waste, and it runs on any of the printers.
//
// It has to be baked into the 3MF. PrusaSlicer's --colorprint-heights CLI flag
// is accepted and then silently ignored — it leaves M600 in the config footer
// and never emits one in the print body, which looks like success.
function customGcodeXml(z: number) {
  return (
    `<?xml version="1.0" encoding="utf-8"?>\n<custom_gcodes_per_print_z>\n` +
    `  <code print_z="${z}" type="0" extruder="1" color="#1A1A1A" extra="" gcode="M600"/>\n` +
    `  <mode value="SingleExtruder"/>\n</custom_gcodes_per_print_z>\n`
  );
}

if (!flag("--no-3mf")) {
  // Clear FIRST — PrusaSlicer shows volumes in this order and it matches the
  // print order, which makes the tool assignment obvious in the GUI.
  const vols = [{ mesh: clear }, { mesh: black }];
  const { xml, ranges } = modelXml(vols);
  const path = join(OUT, `${tag}-2colour.3mf`);
  await write3mf(path, {
    "[Content_Types].xml":
      `<?xml version="1.0" encoding="UTF-8"?>\n` +
      `<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">` +
      `<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>` +
      `<Default Extension="model" ContentType="application/vnd.ms-package.3dmanufacturing-3dmodel+xml"/>` +
      `</Types>\n`,
    "_rels/.rels":
      `<?xml version="1.0" encoding="UTF-8"?>\n` +
      `<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">` +
      `<Relationship Target="/3D/3dmodel.model" Id="rel-1" Type="http://schemas.microsoft.com/3dmanufacturing/2013/01/3dmodel"/>` +
      `</Relationships>\n`,
    "3D/3dmodel.model": xml,
    "Metadata/Slic3r_PE_model.config": configXml(
      ranges,
      ["diffuser, prints first (clear)", "baffle + posts (black)"],
      [EXTRUDER_CLEAR, EXTRUDER_BLACK],
      `mini7seg-${tag}`,
    ),
  });
  console.log(`  -> ${basename(path)}   (MMU, tools ${EXTRUDER_CLEAR}/${EXTRUDER_BLACK})`);

  // Same geometry, both volumes on tool 1, with an M600 at the seam.
  const ccPath = join(OUT, `${tag}-colourchange.3mf`);
  await write3mf(ccPath, {
    "[Content_Types].xml":
      `<?xml version="1.0" encoding="UTF-8"?>\n` +
      `<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">` +
      `<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>` +
      `<Default Extension="model" ContentType="application/vnd.ms-package.3dmanufacturing-3dmodel+xml"/>` +
      `<Default Extension="xml" ContentType="text/xml"/>` +
      `</Types>\n`,
    "_rels/.rels":
      `<?xml version="1.0" encoding="UTF-8"?>\n` +
      `<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">` +
      `<Relationship Target="/3D/3dmodel.model" Id="rel-1" Type="http://schemas.microsoft.com/3dmanufacturing/2013/01/3dmodel"/>` +
      `</Relationships>\n`,
    "3D/3dmodel.model": xml,
    "Metadata/Slic3r_PE_model.config": configXml(
      ranges,
      ["diffuser, prints first (clear)", "baffle + posts (black)"],
      [1, 1],
      `mini7seg-${tag}-cc`,
    ),
    "Metadata/Prusa_Slicer_custom_gcode_per_print_z.xml": customGcodeXml(
      fc.hi[2],
    ),
  });
  console.log(`  -> ${basename(ccPath)}   (single extruder, M600 at z=${fc.hi[2].toFixed(2)})`);
}
