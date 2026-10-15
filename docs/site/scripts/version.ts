import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";
import {
  type FooterVersion,
  type GitInfo,
  footerVersions,
} from "./footer-versions";

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

// The footer's versions, read at build time: git facts in, entries out
// (footer-versions.ts, pure, unit-tested).
const TAG = "[0-9]*.[0-9]*.[0-9]*"; // plain SemVer tags, no "v"

function git(...args: string[]): string {
  try {
    return execFileSync(
      "git",
      ["-C", resolve(here, "..", "..", ".."), ...args],
      {
        encoding: "utf8",
        stdio: ["ignore", "pipe", "ignore"],
      },
    ).trim();
  } catch {
    return "";
  }
}

export function gitInfo(): GitInfo {
  return {
    exactTag: git("describe", "--tags", "--exact-match", "--match", TAG),
    lastTag: git("describe", "--tags", "--abbrev=0", "--match", TAG),
    sha: git("rev-parse", "HEAD"),
  };
}

export function resolveFooterVersions(): FooterVersion[] {
  const own = JSON.parse(
    readFileSync(resolve(here, "..", "package.json"), "utf8"),
  );
  return footerVersions({
    repoUrl: "https://github.com/lucasvmigotto/dottod",
    name: "dottod",
    docsVersion: String(own.version),
    docsPath: "docs/site",
    git: gitInfo(),
  });
}
