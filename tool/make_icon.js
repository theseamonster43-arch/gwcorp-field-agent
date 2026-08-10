// Redraws the GWCORP diamond mark at any size.
//
// The desktop .ico only held a 256px raster, so upscaling it for the iOS
// 1024 slot would just magnify the pixel steps. Drawing it from geometry
// instead gives a clean edge at whatever size is asked for.
//
// Rendered at 3x and box-downsampled for anti-aliasing, then written as a
// PNG using zlib, so this needs no image libraries.

const fs = require('fs');
const zlib = require('zlib');

const SS = 3; // supersample factor

const hex = (h) => [
  parseInt(h.slice(1, 3), 16),
  parseInt(h.slice(3, 5), 16),
  parseInt(h.slice(5, 7), 16),
];

const BG      = hex('#171b2e'); // navy surround
const PANEL   = hex('#080d0b'); // near-black inner face
const G_DARK  = hex('#15803d');
const G_MID   = hex('#22c55e');
const G_LIGHT = hex('#4ade80');

const mix = (a, b, t) => [
  Math.round(a[0] + (b[0] - a[0]) * t),
  Math.round(a[1] + (b[1] - a[1]) * t),
  Math.round(a[2] + (b[2] - a[2]) * t),
];

/** Inside a rounded square centred on (0.5,0.5), half-extent h, corner r. */
function inRounded(x, y, h, r) {
  const dx = Math.abs(x - 0.5);
  const dy = Math.abs(y - 0.5);
  if (dx > h || dy > h) return false;
  const ix = h - r;
  if (dx <= ix || dy <= ix) return true;
  const ox = dx - ix;
  const oy = dy - ix;
  return ox * ox + oy * oy <= r * r;
}

/** Inside a diamond (rotated square) of half-diagonal a. */
const inDiamond = (x, y, a) =>
  Math.abs(x - 0.5) + Math.abs(y - 0.5) <= a;

function sample(x, y) {
  // Outer green frame, dark navy behind it.
  if (!inRounded(x, y, 0.455, 0.115)) return BG;

  // Frame is a diagonal gradient so it does not read as flat.
  const t = ((x + y) / 2 - 0.05) / 0.9;
  const frame = mix(G_DARK, G_LIGHT, Math.max(0, Math.min(1, t)));

  if (!inRounded(x, y, 0.375, 0.075)) return frame;

  // Inner face.
  if (!inDiamond(x, y, 0.215)) return PANEL;

  // Diamond, brightest just above centre so it reads as lit from above.
  const d = Math.hypot(x - 0.5, y - 0.545) / 0.30;
  return mix(G_LIGHT, G_MID, Math.max(0, Math.min(1, d)));
}

function render(size) {
  const n = size * SS;
  const px = Buffer.alloc(size * size * 4);

  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      let r = 0, g = 0, b = 0;
      for (let sy = 0; sy < SS; sy++) {
        for (let sx = 0; sx < SS; sx++) {
          const u = (x * SS + sx + 0.5) / n;
          const v = (y * SS + sy + 0.5) / n;
          const c = sample(u, v);
          r += c[0]; g += c[1]; b += c[2];
        }
      }
      const k = SS * SS;
      const o = (y * size + x) * 4;
      px[o]     = Math.round(r / k);
      px[o + 1] = Math.round(g / k);
      px[o + 2] = Math.round(b / k);
      px[o + 3] = 255; // opaque: the App Store rejects alpha in app icons
    }
  }
  return px;
}

// ── minimal PNG writer ──────────────────────────────────────────────────────
const crcTable = (() => {
  const t = new Int32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    t[n] = c;
  }
  return t;
})();

function crc32(buf) {
  let c = -1;
  for (const byte of buf) c = crcTable[(c ^ byte) & 0xff] ^ (c >>> 8);
  return (c ^ -1) >>> 0;
}

function chunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length);
  const body = Buffer.concat([Buffer.from(type, 'ascii'), data]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(body));
  return Buffer.concat([len, body, crc]);
}

function writePng(path, size, px) {
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(size, 0);
  ihdr.writeUInt32BE(size, 4);
  ihdr[8] = 8;  // bit depth
  ihdr[9] = 6;  // RGBA
  ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0;

  // One filter byte (none) per scanline.
  const raw = Buffer.alloc(size * (size * 4 + 1));
  for (let y = 0; y < size; y++) {
    raw[y * (size * 4 + 1)] = 0;
    px.copy(raw, y * (size * 4 + 1) + 1, y * size * 4, (y + 1) * size * 4);
  }

  fs.writeFileSync(path, Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr),
    chunk('IDAT', zlib.deflateSync(raw, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ]));
}

const out = process.argv[2] || 'assets/icon/app_icon.png';
const size = parseInt(process.argv[3] || '1024', 10);
writePng(out, size, render(size));
console.log(`${out}  ${size}x${size}  ${fs.statSync(out).size} bytes`);
