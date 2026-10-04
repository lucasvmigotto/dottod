import { Link } from "react-router-dom";
import { PageHeader, Section, StatusBadge } from "../components/ui";
import { useI18n } from "../i18n/index";
import type { PageId } from "../i18n/types";

function OnThisPage({ pageId }: { pageId: PageId }) {
  const { content } = useI18n();
  const page = content.pages[pageId];
  if (page.sections.length === 0) return null;
  return (
    <nav aria-label={content.ui.onThisPage} className="hidden xl:block">
      <p className="mb-2 font-display text-xs text-muted">
        {content.ui.onThisPage}
      </p>
      <ul className="space-y-1 border-l border-border pl-3 text-sm">
        {page.sections.map((s) => (
          <li key={s.id}>
            <a href={`#${s.id}`} className="text-muted hover:text-accent">
              {s.heading}
            </a>
          </li>
        ))}
      </ul>
    </nav>
  );
}

export function DocPageView({
  pageId,
  next,
}: {
  pageId: PageId;
  next?: PageId;
}) {
  const { content } = useI18n();
  const page = content.pages[pageId];
  return (
    <div className="flex gap-8">
      <article className="min-w-0 flex-1 space-y-8">
        <PageHeader
          title={page.title}
          summary={page.summary}
          maturity={page.maturity}
        />
        {page.hero && (
          <section
            aria-label={page.hero.title}
            className="overflow-hidden rounded-md border border-border bg-surface"
          >
            <div className="space-y-3 p-6">
              <p className="font-display text-sm text-accent">
                {page.hero.eyebrow}
              </p>
              <h2 className="font-display text-3xl font-semibold tracking-tight text-text">
                {page.hero.title}
              </h2>
              <p className="max-w-[72ch] text-lg text-muted">
                {page.hero.subtitle}
              </p>
              <p>
                <Link
                  to={page.hero.ctaHref}
                  className="inline-block rounded-md bg-accent px-4 py-2 font-medium text-bg hover:bg-accent-hover"
                >
                  {page.hero.ctaLabel}
                </Link>
              </p>
            </div>
            <div className="border-t border-border p-4">
              <pre
                className="overflow-x-auto font-display text-[13px] leading-relaxed"
                aria-label="terminal transcript"
              >
                {page.hero.transcript.map((line) => (
                  <span key={line} className="block">
                    {line.startsWith("➜") ? (
                      <>
                        <span className="font-bold text-accent">➜</span>
                        {line.slice(1)}
                      </>
                    ) : line.startsWith("  ✔") ? (
                      <span className="text-success">{line}</span>
                    ) : line.startsWith("  ✗") ? (
                      <span className="text-danger">{line}</span>
                    ) : (
                      <span className="text-muted">{line}</span>
                    )}
                  </span>
                ))}
              </pre>
            </div>
          </section>
        )}
        {page.sections.map((s) => (
          <Section key={s.id} section={s} />
        ))}
        {next && (
          <p className="border-t border-border pt-4 text-sm">
            {content.ui.nextPage}:{" "}
            <Link
              to={next === "overview" ? "/" : `/${next}`}
              className="text-accent underline underline-offset-4"
            >
              {content.pages[next].title}
            </Link>
          </p>
        )}
      </article>
      <aside className="w-48 shrink-0">
        <div className="sticky top-16">
          <OnThisPage pageId={pageId} />
        </div>
      </aside>
    </div>
  );
}

export function NotFound() {
  const { content } = useI18n();
  return (
    <article className="space-y-4">
      <h1 className="font-display text-3xl font-semibold">
        {content.ui.notFoundTitle}
      </h1>
      <p className="text-muted">{content.ui.notFoundText}</p>
      <p>
        <Link to="/" className="text-accent underline underline-offset-4">
          {content.ui.backHome}
        </Link>
      </p>
      <StatusBadge maturity="unavailable" />
    </article>
  );
}
