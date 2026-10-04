import { mkdirSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
/**
 * Renders the Open Graph image (1200×630) to public/og-image.png, the exact
 * filename the site's index.html advertises.
 *
 *   bun run og
 *
 * Amber prompt glyph on warm graphite, per the docs-site visual direction.
 */
import { chromium } from "@playwright/test";

const here = dirname(fileURLToPath(import.meta.url));
const OUT_DIR = resolve(here, "..", "public");
const TAGLINE =
  process.env.OG_TAGLINE ||
  "Rebuild a Debian workstation with one plain-bash command";
const TITLE = process.env.OG_TITLE || "Documentation";

const html = `<!doctype html>
<html lang="en-US"><head><meta charset="utf-8" />
<style>
  :root { color-scheme: dark; }
  * { box-sizing: border-box; margin: 0; }
  body {
    width: 1200px; height: 630px; overflow: hidden;
    font-family: "IBM Plex Mono", ui-monospace, monospace;
    background: #16181d;
    color: #e7e5df; display: flex; align-items: center; gap: 56px; padding: 72px;
  }
  .mark {
    width: 168px; height: 168px; border-radius: 40px; flex: none;
    background: #1d2026; border: 2px solid #2b2f38;
    display: flex; align-items: center; justify-content: center;
    font-size: 96px; font-weight: 600; color: #e8a33d;
  }
  .brand { font-size: 116px; font-weight: 600; letter-spacing: -2px; line-height: 1; }
  .title { margin-top: 22px; font-size: 40px; font-weight: 500; color: #e7e5df; }
  .tagline { margin-top: 18px; font-size: 28px; color: #9fa2ab; max-width: 780px; }
  .rule { margin-top: 40px; width: 120px; height: 6px; border-radius: 3px; background: #e8a33d; }
</style></head>
<body>
  <div class="mark" aria-hidden="true">➜</div>
  <div>
    <div class="brand">dottod</div>
    <div class="title">${TITLE}</div>
    <div class="tagline">${TAGLINE}</div>
    <div class="rule"></div>
  </div>
</body></html>`;

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1200, height: 630 } });
await page.setContent(html, { waitUntil: "networkidle" });
mkdirSync(OUT_DIR, { recursive: true });
await page.screenshot({ path: resolve(OUT_DIR, "og-image.png") });
await browser.close();
console.log("og-image.png written");
