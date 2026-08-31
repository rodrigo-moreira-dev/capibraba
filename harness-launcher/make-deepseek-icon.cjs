// make-deepseek-icon.cjs
// Generates a multi-size DeepSeek whale .ico from the official favicon.svg
// shipped by the deepseek-harness checkout, replicating the composite used by
// the official DSH desktop icon (gradient rounded square + white whale).
//
// Usage:
//   node make-deepseek-icon.cjs
// Requires 'sharp' resolvable by absolute path (pnpm transitive dep).
const { readFileSync, writeFileSync, mkdirSync } = require("node:fs");
const { dirname, join } = require("node:path");

const SHARP = "C:\\workspace\\Franklin's Project\\deepseek-harness\\node_modules\\.pnpm\\sharp@0.35.3_@types+node@22.20.0\\node_modules\\sharp";
const sharp = require(SHARP);

const FAVICON = "C:\\workspace\\Franklin's Project\\deepseek-harness\\apps\\web\\public\\favicon.svg";
const OUT_DIR = "C:\\workspace\\capibraba\\harness-launcher";
const ICON_SIZES = [256, 128, 64, 48, 32, 24, 16];

const TOP = "#5686FE";
const BOTTOM = "#4176E6";
const GLYPH = "#ffffff";

/* ---------- official whale composite (from icon-maker.mjs) ---------- */
function whaleSvg(pathData, size) {
  const top = TOP, bottom = BOTTOM, glyph = GLYPH;
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 50 50">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="${top}"/>
      <stop offset="1" stop-color="${bottom}"/>
    </linearGradient>
  </defs>
  <rect x="0" y="0" width="50" height="50" rx="12" fill="url(#bg)"/>
  <g transform="translate(5 5) scale(0.8)">
    <path d="${pathData}" fill="${glyph}"/>
  </g>
</svg>`;
}

/* ---------- IC0 encoding (from icon-maker.mjs) ---------- */
const CRC_TABLE = (() => {
  const t = new Int32Array(256);
  for (let n = 0; n < 256; n++) { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; t[n] = c; }
  return t;
})();
function crc32(buf) { let c = 0xffffffff; for (let i = 0; i < buf.length; i++) c = CRC_TABLE[(c ^ buf[i]) & 0xff] ^ (c >>> 8); return (c ^ 0xffffffff) >>> 0; }
function pngChunk(type, data) {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
  const body = Buffer.concat([Buffer.from(type, "ascii"), data]);
  const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(body));
  return Buffer.concat([len, body, crc]);
}
function encodeIco(pngs) {
  const entries = [...pngs.entries()].sort((a, b) => b[0] - a[0]);
  const header = Buffer.alloc(6);
  header.writeUInt16LE(0, 0); header.writeUInt16LE(1, 2); header.writeUInt16LE(entries.length, 4);
  let offset = 6 + 16 * entries.length;
  const parts = [header];
  for (const [size, png] of entries) {
    const entry = Buffer.alloc(16);
    entry[0] = size >= 256 ? 0 : size;
    entry[1] = size >= 256 ? 0 : size;
    entry[2] = 0; entry[3] = 0;
    entry.writeUInt16LE(1, 4); entry.writeUInt16LE(32, 6);
    entry.writeUInt32LE(png.length, 8); entry.writeUInt32LE(offset, 12);
    parts.push(entry);
    offset += png.length;
  }
  for (const [, png] of entries) parts.push(png);
  return Buffer.concat(parts);
}

/* ---------- build ---------- */
async function main() {
  const favicon = readFileSync(FAVICON, "utf8");
  const m = /<path[^>]*\sd="([^"]+)"/.exec(favicon);
  if (!m) throw new Error("no <path d=...> found in favicon.svg");
  const pathData = m[1];
  console.log("whale path length:", pathData.length);

  const pngs = new Map();
  for (const size of ICON_SIZES) {
    const svg = whaleSvg(pathData, size);
    const buf = await sharp(Buffer.from(svg)).png().toBuffer();
    pngs.set(size, buf);
    console.log("rendered", size, buf.length, "bytes");
  }

  const ico = Buffer.concat([encodeIco(pngs), Buffer.alloc(0)]);
  const icoPath = join(OUT_DIR, "deepseek.ico");
  writeFileSync(icoPath, ico);
  console.log("wrote", icoPath, ico.length, "bytes");

  // reference 256 png
  const pngPath = join(OUT_DIR, "deepseek-256.png");
  writeFileSync(pngPath, pngs.get(256));
  console.log("wrote", pngPath, pngs.get(256).length, "bytes");
}

main().catch((e) => { console.error(e); process.exit(1); });
