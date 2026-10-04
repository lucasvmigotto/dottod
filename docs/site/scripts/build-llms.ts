/**
 * Emits LLM-readable output from the SAME typed content the pages render:
 *   <out>/docs/<locale>/<page>.md   one Markdown file per page
 *   <out>/llms.txt                  index per llmstxt.org
 *   <out>/llms-full.txt             every page concatenated
 * Called by `vite.config.ts` during the build, into the served directory
 * (checked-in `public/` assets + this generated Markdown). Also runnable
 * directly (`bun run scripts/build-llms.ts [outDir]`) for tests.
 */
import { mkdirSync, rmSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { enUS } from "../src/i18n/locales/en-US";
import { ptBR } from "../src/i18n/locales/pt-BR";
import {
  type Block,
  type DocsContent,
  LOCALES,
  type Locale,
  type Maturity,
  NAV_GROUPS,
  PAGE_IDS,
} from "../src/i18n/types";

const here = dirname(fileURLToPath(import.meta.url));
const BUNDLES: Record<Locale, DocsContent> = { "pt-BR": ptBR, "en-US": enUS };

const MARKER: Record<Locale, (m: Maturity) => string> = {
  "pt-BR": (m) => {
    const labels: Record<Maturity, string> = {
      implemented: "**Implementado.**",
      partial: "**Parcialmente implementado — partes ainda faltam.**",
      planned: "**Planejado — ainda não implementado.**",
      unavailable: "**Indisponível.**",
      upstream: "**Limitação externa.**",
      na: "**Não aplicável.**",
    };
    return labels[m];
  },
  "en-US": (m) => {
    const labels: Record<Maturity, string> = {
      implemented: "**Implemented.**",
      partial: "**Partially implemented — parts still missing.**",
      planned: "**Planned — not implemented yet.**",
      unavailable: "**Unavailable.**",
      upstream: "**Upstream limitation.**",
      na: "**Not applicable.**",
    };
    return labels[m];
  },
};

function blockToMarkdown(block: Block): string {
  switch (block.kind) {
    case "p":
      return block.text;
    case "ul":
      return block.items.map((i) => `- ${i}`).join("\n");
    case "ol":
      return block.items.map((i, n) => `${n + 1}. ${i}`).join("\n");
    case "code":
      return `${block.caption ? `_${block.caption}_\n\n` : ""}\`\`\`${block.lang}\n${block.code}\n\`\`\``;
    case "table": {
      const head = `| ${block.headers.join(" | ")} |`;
      const sep = `| ${block.headers.map(() => "---").join(" | ")} |`;
      const rows = block.rows.map((r) => `| ${r.join(" | ")} |`).join("\n");
      return `${block.caption ? `_${block.caption}_\n\n` : ""}${head}\n${sep}\n${rows}`;
    }
    case "callout":
      return `> **${block.title ?? "Note"}** — ${block.text}`;
    case "demo":
      return `![${block.alt}](demos/${block.gif})\n\n\`\`\`text\n${block.transcript}\n\`\`\``;
  }
}

export function pageToMarkdown(
  content: DocsContent,
  locale: Locale,
  pageId: (typeof PAGE_IDS)[number],
  forFull = false,
): string {
  const page = content.pages[pageId];
  const lines: string[] = [`# ${page.title}`, "", `> ${page.summary}`, ""];
  if (page.maturity && page.maturity !== "implemented") {
    lines.push(MARKER[locale](page.maturity), "");
  }
  for (const section of page.sections) {
    lines.push(`## ${section.heading}`, "");
    if (section.maturity && section.maturity !== "implemented") {
      lines.push(MARKER[locale](section.maturity), "");
    }
    for (const block of section.blocks) {
      lines.push(blockToMarkdown(block), "");
    }
  }
  if (!forFull) {
    lines.push(
      `_Locale: ${locale}. Maturity labels: Implemented unless marked otherwise._`,
      "",
    );
  }
  return lines.join("\n");
}

export function generateLlmsOutput(outDir: string): void {
  for (const locale of LOCALES) {
    const content = BUNDLES[locale];
    const docsDir = resolve(outDir, "docs", locale);
    mkdirSync(docsDir, { recursive: true });
    for (const pageId of PAGE_IDS) {
      writeFileSync(
        resolve(docsDir, `${pageId}.md`),
        pageToMarkdown(content, locale, pageId),
      );
    }
  }
  const lines: string[] = [
    "# dottod",
    "",
    "> Rebuild a Debian workstation with one plain-bash command. Tasks, guides, and reference for dottod.",
    "",
  ];
  for (const group of NAV_GROUPS) {
    lines.push(`## ${group.key}`, "");
    for (const pageId of group.pages) {
      const page = BUNDLES["en-US"].pages[pageId];
      lines.push(`- [${page.title}](docs/en-US/${pageId}.md): ${page.summary}`);
    }
    lines.push("");
  }
  lines.push(
    "## Optional",
    "",
    "- [Roadmap](docs/en-US/roadmap.md): what is planned but not built.",
    "",
  );
  writeFileSync(resolve(outDir, "llms.txt"), lines.join("\n"));

  const full: string[] = ["# dottod — full documentation (en-US)", ""];
  for (const pageId of PAGE_IDS) {
    full.push(pageToMarkdown(BUNDLES["en-US"], "en-US", pageId, true));
    full.push("---", "");
  }
  writeFileSync(resolve(outDir, "llms-full.txt"), full.join("\n"));
}

if (import.meta.main) {
  const out =
    process.argv[2] ?? resolve(here, "..", "public", "generated-preview");
  rmSync(out, { recursive: true, force: true });
  mkdirSync(out, { recursive: true });
  generateLlmsOutput(out);
  console.log(`llms output written to ${out}`);
}
