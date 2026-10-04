import { existsSync, mkdtempSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { expect, test } from "vitest";
import { generateLlmsOutput, pageToMarkdown } from "../../scripts/build-llms";
import { enUS } from "../../src/i18n/locales/en-US";
import { ptBR } from "../../src/i18n/locales/pt-BR";
import { LOCALES, PAGE_IDS } from "../../src/i18n/types";

test("every page has a .md in every locale", () => {
  const out = mkdtempSync(join(tmpdir(), "llms-"));
  generateLlmsOutput(out);
  for (const locale of LOCALES) {
    for (const pageId of PAGE_IDS) {
      expect(
        existsSync(resolve(out, "docs", locale, `${pageId}.md`)),
        `${locale}/${pageId}.md`,
      ).toBe(true);
    }
  }
  expect(existsSync(resolve(out, "llms.txt"))).toBe(true);
  expect(existsSync(resolve(out, "llms-full.txt"))).toBe(true);
});

test("every llms.txt link resolves inside the output", () => {
  const out = mkdtempSync(join(tmpdir(), "llms-"));
  generateLlmsOutput(out);
  const txt = readFileSync(resolve(out, "llms.txt"), "utf8");
  const links = [...txt.matchAll(/\]\(([^)]+)\)/g)].map((m) => m[1]);
  expect(links.length).toBeGreaterThan(0);
  for (const link of links) {
    expect(existsSync(resolve(out, link)), link).toBe(true);
  }
});

test("llms-full.txt contains every page", () => {
  const out = mkdtempSync(join(tmpdir(), "llms-"));
  generateLlmsOutput(out);
  const full = readFileSync(resolve(out, "llms-full.txt"), "utf8");
  for (const pageId of PAGE_IDS) {
    expect(full).toContain(`# ${enUS.pages[pageId].title}`);
  }
});

test("non-implemented items carry maturity labels in Markdown", () => {
  const roadmap = pageToMarkdown(enUS, "en-US", "roadmap");
  expect(roadmap).toContain("**Planned — not implemented yet.**");
  for (const pageId of PAGE_IDS) {
    const md = pageToMarkdown(enUS, "en-US", pageId);
    expect(md).not.toContain("undefined");
  }
});

test("no page documents planned work as implemented", () => {
  const roadmap = pageToMarkdown(enUS, "en-US", "roadmap");
  expect(roadmap.toLowerCase()).not.toMatch(
    /already (works|implemented)|now available/,
  );
});

test("every demo gif exists in public/demos with alt and transcript", () => {
  const pub = resolve(process.cwd(), "public", "demos");
  for (const pageId of PAGE_IDS) {
    for (const locale of LOCALES) {
      const page = (locale === "en-US" ? enUS : ptBR).pages[pageId];
      for (const section of page.sections) {
        for (const block of section.blocks) {
          if (block.kind === "demo") {
            expect(existsSync(resolve(pub, block.gif)), block.gif).toBe(true);
            expect(block.transcript.length).toBeGreaterThan(0);
            expect(block.alt.length).toBeGreaterThan(0);
          }
        }
      }
    }
  }
});
