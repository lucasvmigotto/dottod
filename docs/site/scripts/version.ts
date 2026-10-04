import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

const here = fileURLToPath(new URL(".", import.meta.url));

/**
 * Version comes from the host repo's CHANGELOG.md (newest released `##
 * X.Y.Z` heading) — dottod has no manifest since the TUI removal.
 * Falls back to the site's own package.json when the CHANGELOG is absent
 * (e.g. a partial build context).
 */
export function resolveVersion(): string {
  if (process.env.DOCS_APP_VERSION) return process.env.DOCS_APP_VERSION;
  try {
    const changelog = readFileSync(
      resolve(here, "..", "..", "..", "CHANGELOG.md"),
      "utf8",
    );
    const match = changelog.match(/^## (\d+\.\d+\.\d+)\b/m);
    if (match) return match[1];
  } catch {
    // fall through to the package.json fallback
  }
  const own = JSON.parse(
    readFileSync(resolve(here, "..", "package.json"), "utf8"),
  );
  return String(own.version);
}
