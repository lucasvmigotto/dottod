import { screen, within } from "@testing-library/react";
import { expect, test } from "vitest";
import { axe } from "vitest-axe";
import * as matchers from "vitest-axe/matchers";
import "vitest-axe/extend-expect";

void matchers;

import { App } from "../../src/App";
import { appRoutes, harness } from "./harness";

test.each(appRoutes())("route %s has no axe violations", async (route) => {
  const { container } = harness(<App />, route);
  expect(await axe(container)).toHaveNoViolations();
});

test("skip link targets the main landmark", () => {
  harness(<App />, "/");
  const skip = screen.getByText(/skip to content/i);
  expect(skip.getAttribute("href")).toBe("#main");
  expect(within(document.body).getByRole("main")).toBeInTheDocument();
});
