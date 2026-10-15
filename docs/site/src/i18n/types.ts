export type Locale = "en-US" | "pt-BR";

export const LOCALES: Locale[] = ["en-US", "pt-BR"];
export const DEFAULT_LOCALE: Locale = "en-US";

/** Truth-first maturity label. Mirrors the project's classification set. */
export type Maturity =
  | "implemented"
  | "partial"
  | "planned"
  | "unavailable"
  | "upstream"
  | "na";

export const TASK_IDS = [
  "shell",
  "fonts",
  "vim",
  "neovim",
  "container",
  "zed",
  "gitconfig",
  "ssh",
  "tools",
  "cargo",
  "bun",
] as const;

export const GUIDE_IDS = [
  "shell",
  "neovim",
  "ssh",
  "containers",
  "fonts",
] as const;

export type PageId =
  | "overview"
  | "start"
  | "tasks"
  | `task-${(typeof TASK_IDS)[number]}`
  | `guide-${(typeof GUIDE_IDS)[number]}`
  | "commands"
  | "config"
  | "concepts"
  | "architecture"
  | "roadmap";

// The route of each page: tasks and guides live under /tasks/ and /guides/
// (see app/router.tsx), the rest at /<id>. One mapping for every link, so a
// page id is never used as a path directly.
export function pathOf(id: PageId): string {
  if (id === "overview") return "/";
  if (id.startsWith("task-")) return `/tasks/${id.slice("task-".length)}`;
  if (id.startsWith("guide-")) return `/guides/${id.slice("guide-".length)}`;
  return `/${id}`;
}

// The page a route shows, for the sidebar's current item ("" if none).
export function pageAt(pathname: string): PageId | "" {
  return PAGE_IDS.find((id) => pathOf(id) === (pathname || "/")) ?? "";
}

export const PAGE_IDS: PageId[] = [
  "overview",
  "start",
  "tasks",
  ...TASK_IDS.map((t) => `task-${t}` as PageId),
  ...GUIDE_IDS.map((g) => `guide-${g}` as PageId),
  "commands",
  "config",
  "concepts",
  "architecture",
  "roadmap",
];

export type Block =
  | { kind: "p"; text: string }
  | { kind: "ul"; items: string[] }
  | { kind: "ol"; items: string[] }
  | { kind: "code"; lang: string; code: string; caption?: string }
  | { kind: "table"; headers: string[]; rows: string[][]; caption?: string }
  | {
      kind: "callout";
      tone: "info" | "warning" | "success";
      title?: string;
      text: string;
    }
  | { kind: "demo"; gif: string; alt: string; transcript: string };

export interface Section {
  id: string;
  heading: string;
  maturity?: Maturity;
  blocks: Block[];
}

export interface Hero {
  eyebrow: string;
  title: string;
  subtitle: string;
  ctaLabel: string;
  ctaHref: string;
  transcript: string[];
}

export interface DocPage {
  id: PageId;
  /** SEO/heading title. */
  title: string;
  /** One-line description used by nav, search and llms.txt. */
  summary: string;
  maturity?: Maturity;
  hero?: Hero;
  sections: Section[];
}

export interface UiStrings {
  siteName: string;
  siteTagline: string;
  skipToContent: string;
  menu: string;
  close: string;
  search: string;
  searchPlaceholder: string;
  searchNoResults: string;
  searchSuggestions: string;
  language: string;
  theme: string;
  themeDark: string;
  themeLight: string;
  breadcrumbHome: string;
  onThisPage: string;
  version: string;
  copy: string;
  copied: string;
  footerNote: string;
  nextPage: string;
  maturityLabels: Record<Maturity, string>;
  groupLabels: Record<string, string>;
  notFoundTitle: string;
  notFoundText: string;
  backHome: string;
}

export interface DocsContent {
  ui: UiStrings;
  pages: Record<PageId, DocPage>;
}

/** Page grouping, shared across locales (structure is not translated). */
export interface NavGroup {
  key: string;
  pages: PageId[];
}

export const NAV_GROUPS: NavGroup[] = [
  { key: "start", pages: ["overview", "start"] },
  { key: "tasks", pages: ["tasks"] },
  {
    key: "guides",
    pages: [
      "guide-shell",
      "guide-neovim",
      "guide-ssh",
      "guide-containers",
      "guide-fonts",
    ],
  },
  { key: "reference", pages: ["commands", "config"] },
  { key: "project", pages: ["concepts", "architecture", "roadmap"] },
];
