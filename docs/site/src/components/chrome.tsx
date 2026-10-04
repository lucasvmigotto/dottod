import { useEffect, useMemo, useRef, useState } from "react";
import { Link, useLocation } from "react-router-dom";
import { useI18n } from "../i18n/index";
import { NAV_GROUPS, PAGE_IDS, type PageId } from "../i18n/types";

declare const __APP_VERSION__: string;

export function SkipLink() {
  const { content } = useI18n();
  return (
    <a
      href="#main"
      className="sr-only focus:not-sr-only focus:absolute focus:left-4 focus:top-4 focus:z-50 focus:rounded focus:bg-accent focus:px-3 focus:py-2 focus:text-bg"
    >
      {content.ui.skipToContent}
    </a>
  );
}

export function Search() {
  const { content } = useI18n();
  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState("");
  const inputRef = useRef<HTMLInputElement>(null);
  const closeRef = useRef<HTMLButtonElement>(null);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (
        e.key === "/" &&
        !(e.target instanceof HTMLInputElement) &&
        !(e.target instanceof HTMLTextAreaElement)
      ) {
        e.preventDefault();
        setOpen(true);
      }
      if (e.key === "Escape") setOpen(false);
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, []);

  useEffect(() => {
    if (open) inputRef.current?.focus();
  }, [open]);

  const results = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return [];
    return PAGE_IDS.map((id) => content.pages[id as PageId])
      .filter((p) => `${p.title} ${p.summary}`.toLowerCase().includes(q))
      .slice(0, 8);
  }, [query, content]);

  return (
    <div className="relative">
      <button
        type="button"
        onClick={() => setOpen((o) => !o)}
        aria-expanded={open}
        className="rounded border border-border bg-surface px-3 py-1.5 font-display text-sm text-muted hover:text-text"
      >
        {content.ui.search}{" "}
        <kbd className="ml-1 rounded border border-border px-1 text-xs">/</kbd>
      </button>
      {open && (
        <div className="absolute right-0 z-40 mt-2 w-80 rounded-md border border-border bg-surface p-3 shadow-none">
          <input
            ref={inputRef}
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder={content.ui.searchPlaceholder}
            aria-label={content.ui.search}
            className="w-full rounded border border-border bg-bg px-2 py-1.5 text-sm text-text"
          />
          <ul
            aria-label={content.ui.search}
            className="mt-2 max-h-64 space-y-1 overflow-y-auto"
          >
            {results.map((p) => (
              <li key={p.id}>
                <Link
                  to={p.id === "overview" ? "/" : `/${p.id}`}
                  onClick={() => {
                    setOpen(false);
                    setQuery("");
                    closeRef.current?.focus();
                  }}
                  className="block rounded px-2 py-1.5 text-sm hover:bg-bg"
                >
                  <span className="font-medium text-text">{p.title}</span>
                  <span className="block truncate text-xs text-muted">
                    {p.summary}
                  </span>
                </Link>
              </li>
            ))}
            {query.trim() !== "" && results.length === 0 && (
              <li className="px-2 py-1.5 text-sm text-muted">
                {content.ui.searchNoResults.replace("{query}", query.trim())}{" "}
                <span className="text-xs">{content.ui.searchSuggestions}</span>
              </li>
            )}
          </ul>
          <button
            ref={closeRef}
            type="button"
            onClick={() => setOpen(false)}
            className="mt-2 text-xs text-muted hover:text-text"
          >
            {content.ui.close}
          </button>
        </div>
      )}
    </div>
  );
}

export function Header({ onMenu }: { onMenu: () => void }) {
  const { content, locale, setLocale, theme, toggleTheme } = useI18n();
  return (
    <header className="sticky top-0 z-30 border-b border-border bg-bg/95 backdrop-blur">
      <div className="mx-auto flex max-w-6xl items-center gap-3 px-4 py-3">
        <button
          type="button"
          onClick={onMenu}
          aria-label={content.ui.menu}
          className="rounded p-2 text-muted hover:text-text lg:hidden"
        >
          <span aria-hidden="true" className="block h-0.5 w-5 bg-current" />
          <span
            aria-hidden="true"
            className="mt-1 block h-0.5 w-5 bg-current"
          />
          <span
            aria-hidden="true"
            className="mt-1 block h-0.5 w-5 bg-current"
          />
        </button>
        <Link
          to="/"
          className="flex items-center gap-2 font-display font-semibold text-text"
        >
          <span
            aria-hidden="true"
            className="inline-flex size-6 items-center justify-center rounded bg-surface font-bold text-accent"
          >
            ➜
          </span>
          {content.ui.siteName}
        </Link>
        <span className="hidden rounded border border-border px-1.5 py-0.5 font-display text-xs text-muted sm:inline">
          v{__APP_VERSION__}
        </span>
        <div className="ml-auto flex items-center gap-2">
          <Search />
          <label className="sr-only" htmlFor="lang-select">
            {content.ui.language}
          </label>
          <select
            id="lang-select"
            value={locale}
            onChange={(e) => setLocale(e.target.value as typeof locale)}
            className="rounded border border-border bg-surface px-2 py-1.5 text-sm text-text"
          >
            <option value="en-US">EN</option>
            <option value="pt-BR">PT</option>
          </select>
          <button
            type="button"
            onClick={toggleTheme}
            aria-label={content.ui.theme}
            title={
              theme === "dark" ? content.ui.themeLight : content.ui.themeDark
            }
            className="rounded border border-border px-2 py-1.5 text-sm text-muted hover:text-text"
          >
            <span aria-hidden="true">{theme === "dark" ? "◐" : "◑"}</span>
          </button>
        </div>
      </div>
    </header>
  );
}

export function Sidebar({
  mobile,
  onNavigate,
}: {
  mobile: boolean;
  onNavigate?: () => void;
}) {
  const { content } = useI18n();
  const location = useLocation();
  const current = location.pathname.replace(/^\//, "") || "overview";
  return (
    <nav
      aria-label={content.ui.menu}
      className={
        mobile
          ? "space-y-4"
          : "sticky top-16 max-h-[calc(100vh-4rem)] space-y-4 overflow-y-auto"
      }
    >
      {NAV_GROUPS.map((g) => (
        <div key={g.key}>
          <p className="mb-1 font-display text-xs text-muted">
            {content.ui.groupLabels[g.key] ?? g.key}
          </p>
          <ul className="space-y-0.5 border-l border-border pl-3">
            {g.pages.map((id) => {
              const page = content.pages[id as PageId];
              const active =
                current === id || (id === "overview" && current === "");
              return (
                <li key={id}>
                  <Link
                    to={id === "overview" ? "/" : `/${id}`}
                    onClick={onNavigate}
                    aria-current={active ? "page" : undefined}
                    className={`block rounded px-2 py-1 text-sm ${active ? "bg-surface font-medium text-accent" : "text-muted hover:text-text"}`}
                  >
                    {page.title}
                  </Link>
                </li>
              );
            })}
          </ul>
        </div>
      ))}
    </nav>
  );
}

export function Footer() {
  const { content } = useI18n();
  return (
    <footer className="border-t border-border py-6 text-sm text-muted">
      <p>{content.ui.footerNote}</p>
    </footer>
  );
}

export function Layout({ children }: { children: React.ReactNode }) {
  const [menuOpen, setMenuOpen] = useState(false);
  return (
    <div className="min-h-screen bg-bg text-text">
      <SkipLink />
      <Header onMenu={() => setMenuOpen(true)} />
      {menuOpen && (
        <div className="fixed inset-0 z-40 bg-bg p-4 lg:hidden">
          <button
            type="button"
            onClick={() => setMenuOpen(false)}
            aria-label="close"
            className="mb-4 rounded border border-border px-3 py-1.5 text-sm"
          >
            ✕
          </button>
          <Sidebar mobile onNavigate={() => setMenuOpen(false)} />
        </div>
      )}
      <div className="mx-auto flex max-w-6xl gap-8 px-4 py-8">
        <aside className="hidden w-56 shrink-0 lg:block">
          <Sidebar mobile={false} />
        </aside>
        <main id="main" className="min-w-0 flex-1 space-y-10">
          {children}
          <Footer />
        </main>
      </div>
    </div>
  );
}
