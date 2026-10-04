import type { ReactNode } from "react";
import { useState } from "react";
import { useI18n } from "../i18n/index";
import type { Block, Maturity, Section as SectionT } from "../i18n/types";

export function StatusBadge({ maturity }: { maturity: Maturity }) {
  const { content } = useI18n();
  const label = content.ui.maturityLabels[maturity];
  const tone: Record<Maturity, string> = {
    implemented: "border-success/50 text-success",
    partial: "border-warning/50 text-warning",
    planned: "border-accent/50 text-accent",
    unavailable: "border-danger/50 text-danger",
    upstream: "border-danger/50 text-danger",
    na: "border-border text-muted",
  };
  return (
    <span
      className={`inline-flex items-center gap-1.5 rounded-full border px-2.5 py-0.5 font-display text-xs font-medium ${tone[maturity]}`}
    >
      <span aria-hidden="true" className="size-1.5 rounded-full bg-current" />
      {label}
    </span>
  );
}

function blockKey(block: Block, fallback: string): string {
  switch (block.kind) {
    case "p":
      return `p-${block.text.slice(0, 48)}`;
    case "ul":
    case "ol":
      return `${block.kind}-${block.items[0] ?? fallback}`;
    case "code":
      return `code-${block.lang}-${block.caption ?? block.code.slice(0, 32)}`;
    case "table":
      return `table-${block.headers.join(",")}`;
    case "callout":
      return `callout-${block.title ?? block.text.slice(0, 32)}`;
    case "demo":
      return `demo-${block.gif}`;
  }
}

export function Section({ section }: { section: SectionT }) {
  return (
    <section
      id={section.id}
      aria-labelledby={`${section.id}-h`}
      className="scroll-mt-24"
    >
      <div className="mb-3 flex flex-wrap items-center gap-3 border-b border-border pb-2">
        <h2
          id={`${section.id}-h`}
          className="font-display text-xl font-semibold tracking-tight text-text"
        >
          {section.heading}
        </h2>
        {section.maturity && <StatusBadge maturity={section.maturity} />}
      </div>
      <div className="space-y-4 text-[15px] leading-relaxed text-muted">
        {section.blocks.map((b, n) => (
          <BlockView
            key={`${section.id}-${blockKey(b, String(n))}`}
            block={b}
          />
        ))}
      </div>
    </section>
  );
}

export function Callout({
  tone,
  title,
  text,
}: {
  tone: "info" | "warning" | "success";
  title?: string;
  text: string;
}) {
  const tones = {
    info: "border-accent/40 bg-accent/5",
    warning: "border-warning/40 bg-warning/5",
    success: "border-success/40 bg-success/5",
  };
  return (
    <div className={`rounded-md border p-4 ${tones[tone]}`} role="note">
      {title && <p className="mb-1 font-medium text-text">{title}</p>}
      <p>{text}</p>
    </div>
  );
}

export function CodeBlock({
  lang,
  code,
  caption,
}: {
  lang: string;
  code: string;
  caption?: string;
}) {
  const { content } = useI18n();
  const [copied, setCopied] = useState(false);
  const copy = async () => {
    try {
      await navigator.clipboard.writeText(code);
    } catch {
      const ta = document.createElement("textarea");
      ta.value = code;
      document.body.appendChild(ta);
      ta.select();
      document.execCommand("copy");
      document.body.removeChild(ta);
    }
    setCopied(true);
    window.setTimeout(() => setCopied(false), 1500);
  };
  return (
    <figure className="overflow-hidden rounded-md border border-border bg-surface">
      {caption && (
        <figcaption className="border-b border-border px-4 py-2 font-display text-xs text-muted">
          {caption}
        </figcaption>
      )}
      <div className="relative">
        <pre className="overflow-x-auto p-4 font-display text-[13px] leading-relaxed text-text">
          <code data-lang={lang}>{code}</code>
        </pre>
        <button
          type="button"
          onClick={copy}
          aria-live="polite"
          className="absolute right-2 top-2 rounded border border-border bg-bg px-2 py-1 font-display text-xs text-muted hover:text-accent"
        >
          {copied ? content.ui.copied : content.ui.copy}
        </button>
      </div>
    </figure>
  );
}

export function BlockView({ block }: { block: Block }) {
  switch (block.kind) {
    case "p":
      return <p>{block.text}</p>;
    case "ul":
      return (
        <ul className="list-disc space-y-1 pl-5">
          {block.items.map((i) => (
            <li key={i}>{i}</li>
          ))}
        </ul>
      );
    case "ol":
      return (
        <ol className="list-decimal space-y-1 pl-5">
          {block.items.map((i) => (
            <li key={i}>{i}</li>
          ))}
        </ol>
      );
    case "code":
      return (
        <CodeBlock
          lang={block.lang}
          code={block.code}
          caption={block.caption}
        />
      );
    case "table":
      return (
        <div className="overflow-x-auto">
          <table className="w-full border-collapse text-left text-sm">
            {block.caption && (
              <caption className="pb-2 text-left font-display text-xs text-muted">
                {block.caption}
              </caption>
            )}
            <thead>
              <tr className="border-b border-border font-display text-xs text-muted">
                {block.headers.map((h) => (
                  <th key={h} scope="col" className="px-3 py-2 font-medium">
                    {h}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {block.rows.map((r) => (
                <tr
                  key={r.join("|")}
                  className="border-b border-border last:border-0"
                >
                  {r.map((c) => (
                    <td key={c} className="px-3 py-2 align-top">
                      {c}
                    </td>
                  ))}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      );
    case "callout":
      return (
        <Callout tone={block.tone} title={block.title} text={block.text} />
      );
    case "demo":
      return (
        <figure className="space-y-2">
          <img
            src={`${import.meta.env.BASE_URL}demos/${block.gif}`}
            alt={block.alt}
            loading="lazy"
            className="w-full rounded-md border border-border"
          />
          <figcaption className="sr-only">{block.alt}</figcaption>
          <details className="text-sm">
            <summary className="cursor-pointer text-muted hover:text-text">
              Text transcript
            </summary>
            <pre className="mt-2 overflow-x-auto rounded-md border border-border bg-surface p-4 font-display text-[13px] leading-relaxed">
              <code>{block.transcript}</code>
            </pre>
          </details>
        </figure>
      );
  }
}

export function PageHeader({
  eyebrow,
  title,
  summary,
  maturity,
  children,
}: {
  eyebrow?: string;
  title: string;
  summary: string;
  maturity?: Maturity;
  children?: ReactNode;
}) {
  return (
    <header className="space-y-3">
      {eyebrow && <p className="font-display text-sm text-accent">{eyebrow}</p>}
      <div className="flex flex-wrap items-center gap-3">
        <h1 className="font-display text-4xl font-semibold tracking-tight text-text">
          {title}
        </h1>
        {maturity && <StatusBadge maturity={maturity} />}
      </div>
      <p className="max-w-[72ch] text-lg leading-relaxed text-muted">
        {summary}
      </p>
      {children}
    </header>
  );
}
