import type { ReactNode } from "react";
import { useI18n } from "../i18n/index";
import type { Block, MatrixState } from "../i18n/types";
import { DISTRO_ICONS, STATUS_PATHS } from "./icons";

type MatrixBlock = Extract<Block, { kind: "matrix" }>;

// Same tones as StatusBadge, so a state reads the same everywhere.
const TONE: Record<MatrixState, string> = {
  ok: "text-success",
  partial: "text-warning",
  pending: "text-accent",
  notrun: "text-muted",
  unsupported: "text-danger",
  na: "text-muted",
};

function Glyph({ path, className }: { path: string; className: string }) {
  return (
    <svg
      viewBox="0 0 24 24"
      aria-hidden="true"
      focusable="false"
      className={className}
    >
      <path d={path} fill="currentColor" />
    </svg>
  );
}

// A focusable icon whose text shows as a tooltip on hover and on keyboard
// focus, and is the accessible name for screen readers.
function Tip({ text, children }: { text: string; children: ReactNode }) {
  return (
    <span
      role="img"
      aria-label={text}
      // biome-ignore lint/a11y/noNoninteractiveTabindex: focus reveals the tooltip for keyboard users
      tabIndex={0}
      className="group relative inline-flex rounded outline-none focus-visible:ring-2 focus-visible:ring-accent"
    >
      {children}
      <span
        aria-hidden="true"
        className="pointer-events-none absolute bottom-full left-1/2 z-20 mb-2 hidden w-max max-w-56 -translate-x-1/2 rounded border border-border bg-surface px-2 py-1 text-left font-sans text-xs font-normal text-text shadow-lg group-hover:block group-focus-visible:block"
      >
        {text}
      </span>
    </span>
  );
}

export function Matrix({ block }: { block: MatrixBlock }) {
  const { content } = useI18n();
  const labels = content.ui.matrixLabels;
  // Legend: only the states this table uses, in their canonical order.
  const used = new Set(block.rows.flatMap((r) => r.cells.map((c) => c.state)));
  const states = (Object.keys(labels) as MatrixState[]).filter((s) =>
    used.has(s),
  );
  return (
    <div>
      <table className="w-full border-collapse text-left text-sm">
        <thead>
          <tr className="border-b border-border">
            <th scope="col" className="px-3 py-2">
              <span className="sr-only">{content.ui.matrixRowHeader}</span>
            </th>
            {block.columns.map((c) => (
              <th
                key={c.distro}
                scope="col"
                className="px-2 py-2 text-center text-text"
              >
                <Tip text={c.label}>
                  <Glyph
                    path={DISTRO_ICONS[c.distro].path}
                    className="size-5"
                  />
                </Tip>
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {block.rows.map((r) => (
            <tr key={r.label} className="border-b border-border last:border-0">
              <th scope="row" className="px-3 py-2 text-left font-normal">
                {r.label}
              </th>
              {r.cells.map((cell, i) => {
                const column = block.columns[i]?.label ?? "";
                const label = labels[cell.state];
                return (
                  <td
                    key={`${r.label}-${column}`}
                    className="px-2 py-2 text-center align-middle"
                  >
                    <Tip
                      text={`${column}: ${label}${cell.note ? ` — ${cell.note}` : ""}`}
                    >
                      <Glyph
                        path={STATUS_PATHS[cell.state]}
                        className={`size-5 ${TONE[cell.state]}`}
                      />
                    </Tip>
                  </td>
                );
              })}
            </tr>
          ))}
        </tbody>
      </table>
      <ul
        aria-label={content.ui.matrixLegend}
        className="mt-3 flex flex-wrap gap-x-4 gap-y-1 text-xs text-muted"
      >
        {states.map((s) => (
          <li key={s} className="inline-flex items-center gap-1.5">
            <Glyph path={STATUS_PATHS[s]} className={`size-4 ${TONE[s]}`} />
            {labels[s]}
          </li>
        ))}
      </ul>
    </div>
  );
}
