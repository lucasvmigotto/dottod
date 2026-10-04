import { cleanup, screen } from "@testing-library/react";
import { expect, test } from "vitest";
import { App } from "../../src/App";
import { PAGE_IDS, TASK_IDS } from "../../src/i18n/types";
import { harness } from "../a11y/harness";

test("every page id has a route that renders its title", async () => {
  const byId: Record<string, string> = { overview: "/" };
  for (const t of TASK_IDS) byId[`task-${t}`] = `/tasks/${t}`;
  for (const id of PAGE_IDS) {
    const route =
      byId[id] ??
      (id.startsWith("guide-") ? `/guides/${id.slice(6)}` : `/${id}`);
    const { unmount } = harness(<App />, route);
    await screen.findByRole("main");
    expect(document.body.textContent ?? "").not.toBe("");
    unmount();
    cleanup();
  }
});

test("deep link to a task page renders the task, not the 404", () => {
  harness(<App />, "/tasks/neovim");
  expect(screen.getByRole("heading", { name: /neovim/i })).toBeInTheDocument();
  expect(screen.queryByText(/doesn't exist/i)).not.toBeInTheDocument();
});

test("unknown route renders the 404 page", () => {
  harness(<App />, "/no-such-page");
  expect(screen.getByText(/doesn't exist/i)).toBeInTheDocument();
});
