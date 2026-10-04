# dottod documentation site — UX and language vision

Status: Draft
Scope: the **`docs/site/` documentation website** for dottod (the product is
a plain-bash Debian workstation bootstrap; the site documents it).
Produced by: `frontend:uiux` (scoped to the docs site), 2026-10-04.

## Summary

A documentation site for **one person who resets their workstation and
re-runs dottod** — a runbook that happens to be beautiful. It reads as a
terminal, not a SaaS landing page: a real bootstrap transcript is the hero,
monospace carries the voice, and a single amber accent marks the prompt and
links. Every page answers one question: *what do I run next, and is it safe
to run again?* Dark-first, light available. English (en-US) and Brazilian
Portuguese (pt-BR).

## Personas & jobs

1. **The maintainer, mid-reset** (primary). Freshly reinstalled Debian box,
   terminal open, no dotfiles. Job: get the machine back without thinking;
   recover one failed task; know whether re-running is safe.
2. **A returning maintainer** (secondary). Check a flag, env default, or task
   behaviour months later; read the roadmap for what isn't built.
3. **A curious developer from the hub** (tertiary). Understand in a minute.

## Principles

1. **The transcript is the documentation.** Real command output, never paraphrased.
2. **Every page ends in a next action.**
3. **Re-running is safe, and the site says so everywhere.**
4. **One accent, spent in one place** (amber = prompt + links only).
5. **Maturity is never implied** (Implemented / Partially / Planned / Unavailable).

## Information architecture

```
/dottod/
├── Overview          /            what it is · why plain bash · tasks at a glance
├── Getting started   /start       clone → run → verify → recover after a reset
├── Tasks             /tasks       12 tasks, flags, env, idempotency (+ /tasks/<task>)
├── Guides            /guides      shell · neovim · ssh · containers · fonts
├── Reference         /commands  /config   bootstrap flags (from --help) · _DOT_* vars
├── Concepts          /concepts    Task · Profile · Healing · runtime states · idempotency
├── Architecture      /architecture as-is topology, stack, release flow
└── Roadmap           /roadmap     spec statuses; Planned items, clearly separated
```

Navigation: persistent left sidebar, top bar (name, search `/`, language,
theme). Chosen over tabs because the corpus is deep, not broad. Glossary
terms throughout; no synonyms.

## Key flows

1. **Back on the machine (primary).** Overview → Getting started → copy
   clone + `./bin/bootstrap.sh` → verification checklist. Failure branch: a
   task failed → task page Troubleshooting → log `/tmp/dottod/<task>.log` →
   re-run one task.
2. **Add one capability.** Tasks → task page → `--only <task>`.
3. **Confirm a flag.** Search → Command reference anchor.
4. **See what's not real yet.** Roadmap → Planned → spec.

## Screen inventory

| Screen | Purpose | Primary action |
|---|---|---|
| Overview | What dottod is | Go to Getting started |
| Getting started | Reproduce the machine | Copy the bootstrap command |
| Tasks index / task page | Find and run one task | `--only <task>` |
| Command / Config reference | All flags and `_DOT_*` vars | Copy |
| Guide | Deep topic | Follow steps |
| Concepts | Vocabulary | Read a term |
| Architecture | How it fits | Follow the release flow |
| Roadmap | Status of unbuilt work | Open a spec |

Desktop (Overview — the memorable screen):

```text
┌───────────────────────────────────────────────────────────────────────┐
│ dottod            Tasks  Guides  Reference  Search(/)   EN/PT  ◐      │
├──────────┬────────────────────────────────────────────────────────────┤
│ Overview │  dottod                                                    │
│ Start    │  Rebuild a Debian workstation with one plain-bash command. │
│ Tasks ▾  │  ➜ ~/codes/dottod  ./bin/bootstrap.sh                      │
│ Guides ▾ │  ▶ Bootstrap starting (11 task(s))                         │
│ Referen… │    ✔ shell: PASS      ✔ fonts: PASS                        │
│ Concepts │    ✗ neovim: FAIL  → heal: _DOT_NVIM_ALLOW_TARBALL=1 …      │
│ Archit…  │  ── task ───────────────────────────────────────────────   │
│ Roadmap  │  What it does · Flags · Env · Safe to re-run  [Implemented]│
└──────────┴────────────────────────────────────────────────────────────┘
```

Mobile: sidebar → drawer; transcript stays first; code scrolls with copy;
theme/language move into the menu.

## Visual direction & draft tokens

Two-pass method (draft → review, below).

- **Draft — color (dark, default)** warm graphite + amber (not near-black/acid-green):
  `color.bg #16181d`, `color.surface #1d2026`, `color.border #2b2f38`,
  `color.text #e7e5df`, `color.text.muted #9fa2ab`, `color.accent #e8a33d`,
  `color.accent.hover #f2b455`, `color.success #7fb069`, `color.warning #e8a33d`,
  `color.danger #e07a5f`.
- **Color (light)**: `color.bg #f5f6f8` (cool paper, not cream),
  `color.surface #ffffff`, `color.text #1b1d22`, `color.text.muted #565a63`,
  `color.accent #a9690a`.
- **Type**: IBM Plex **Mono** (500/600) — headings, prompt, data labels,
  code; IBM Plex **Sans** (400/500) — prose. Scale (rem): 2.25/1.5/1.25/1/
  0.9375/0.8125. Prose ≤ 72ch.
- **Layout**: sidebar + single ~72ch column + "on this page"; **rules over
  cards**; `radius.control 6px`; no shadows.
- **Hero**: a real bootstrap transcript.
- **Motion**: near-none; one reduced-motion-aware transcript fade; hover = color only.

Draft tokens: `color.*` (above), `font.display|body|mono`, `font.size.1..6`,
`space.1..6`, `radius.control|surface`, `motion.duration.short|base`, `motion.ease`.

**Review against AI defaults — and what changed:**

- Near-black + acid-green (#2): avoided (graphite + amber).
- Cream + serif + terracotta (#1): avoided (cool paper light theme, mono).
- SaaS card kit (#4) / template chrome (#5): departed — no uniform cards, no
  shadows, no ALL-CAPS eyebrows, no `A · B · C` meta, no `WORD — fragment`,
  no `→` on links. `➜` appears only where it is literally a prompt.
- Broadsheet (#3): avoided (single column, small non-zero radius).
- Revised: first draft used a card grid for the Tasks index → changed to a
  rule-separated list.

## Interaction patterns & states

- Copy on every code block (`Copy` → `Copied`, same verb).
- Search defer-loads its index (skeleton), then instant; empty:
  “No pages match “{q}”. Try “bootstrap”, “neovim”, or “--ui”.”
- 404: “That page doesn't exist. The pages are listed on the left.”
- Product warnings (e.g. ssh merge) as `Callout`s; site itself has no
  destructive actions.
- Theme/language persisted in `localStorage`, applied before first paint;
  `<html lang>` synced.

## Responsive behavior

Breakpoints by content: `~52rem` (sidebar → drawer), `~36rem` (padding,
transcript size). "On this page" → top anchor menu on mobile. Nothing hidden
is unreachable. Touch ≥ 44px; focus ring `:focus-visible` 2px accent, 2px offset.

## Accessibility targets

WCAG 2.2 AA. Contrast ≥ 4.5:1 body in both themes (accent ≥ 3:1 for large
text, links underlined). Keyboard: skip link, sidebar, search (`/`,
`Cmd/Ctrl-K` listbox with arrows), theme, language; overlays restore focus.
`prefers-reduced-motion` disables the fade. Per-locale `<html lang>`;
polite live region for search/copy results.

## Voice & tone

Plain, technical, unshowy. Sentence case, active voice, no marketing.

- Onboarding: “dottod rebuilds a Debian workstation with one plain-bash
  command. No plugins, no frameworks — the shell is the tool.”
- Error: “Neovim 0.10.4 is below the 0.11 minimum. Install the tarball build
  with `_DOT_NVIM_ALLOW_TARBALL=1 ./bin/neovim.sh`, or use trixie-backports.”
- Success: “Bootstrap complete. Re-run it any time — every task checks before it acts.”

## Terminology

Uses `brief.md`'s glossary: **Task**, **Profile**, **Configured/Selected/
Usable**, **Healing**. UI-only: Overview, Getting started, Tasks, Guides,
Reference (Commands, Configuration), Concepts, Architecture, Roadmap. Never
“script” for a task. Identifiers (commands, flags, `_DOT_*`, paths) are never
translated or reworded.

## Microcopy patterns

CTA verbs keep their name (“Copy”→“Copied”; “Run” not “Execute”). Errors =
what + fix, no apology. Empty states invite action. Sentence-case labels;
placeholders are examples (`--only shell,neovim`). Locale-aware dates
(`en-US` `July 4, 2026`; `pt-BR` `4 de julho de 2026`).

## Key-screen copy (real, keyed)

- `hero.title` “dottod” · `hero.subtitle` “Rebuild a Debian workstation with
  one plain-bash command.” · `hero.cta` “Get started”
- `overview.why.title` “Plain bash, on purpose” · `overview.why.body` “No
  plugins, no frameworks, no prompt stack. One entry point, one log per task,
  and every task safe to run twice.”
- `start.promise` “Re-run it any time. Every task checks before it acts.”
- `tasks.idempotent.yes` “Safe to re-run” · `tasks.idempotent.no` “Runs once —
  not automatic”
- `error.task.failed` “Task failed. Read the log, fix the cause, re-run just
  that task:” + `/tmp/dottod/<task>.log`
- `search.empty`, `theme.toggle`, `lang.current`

## Localization

en-US (default) + pt-BR, typed `ui`/`docs` namespaces (missing translation =
type error). ~30% text expansion allowance. Not translated: commands, flags,
env vars, code, paths, product name. Browser detection → `localStorage` →
en-US fallback; `<html lang>` + `alternate` per locale.

## Brand mark

A monospace prompt glyph (`➜`/`$`) in amber inside a small rounded square;
favicon and OG image derived from it. (No pre-existing mark.)

## Open questions

1. `vhs` demos — deferred (not installed); follow-up phase.
2. Historical pages (`introspec`/`retrofit`, the removed zsh/sysinfo stack)
   stay repo-only; Architecture links to them as history.

## Decision log

- Primary reader = maintainer mid-reset → runbook IA, copy-first.
- Distinct, terminal-grounded identity (amber/graphite, IBM Plex Mono/Sans,
  transcript hero); coherence with the hub kept via typography + maturity badges.
- Layout departs the SaaS-card kit (rules over cards).
- Dark-first + persisted toggle; light = cool paper.
- Version badge from `CHANGELOG.md`'s newest released heading (no manifest).
- Site at `docs/site/`, deploys to hub prefix `dottod/`
  (`environment: dottod-docs`); hub registration deferred.
