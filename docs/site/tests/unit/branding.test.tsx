import { screen } from "@testing-library/react";
import { expect, test } from "vitest";
import { App } from "../../src/App";
import { harness } from "../a11y/harness";

test("brand voice: title, transcript hero, no filler", async () => {
  harness(<App />, "/");
  await screen.findByRole("main");
  expect(document.title).toMatch(/dottod/i);
  expect(screen.getByLabelText("terminal transcript")).toBeInTheDocument();
  expect(
    screen.getByText("./bin/bootstrap.sh", { exact: false }),
  ).toBeInTheDocument();
  const body = document.body.textContent ?? "";
  expect(body).not.toMatch(/lorem ipsum/i);
  expect(body).not.toMatch(/all caps eyebrow/i);
});

test("maturity is visible, not color-only", () => {
  harness(<App />, "/roadmap");
  expect(screen.getAllByText("Planned").length).toBeGreaterThan(0);
});
