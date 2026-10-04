import { cleanup, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { expect, test } from "vitest";
import { App } from "../../src/App";
import { harness } from "../a11y/harness";

test("language switcher changes UI chrome and persists", async () => {
  cleanup();
  const user = userEvent.setup();
  window.localStorage.clear();
  harness(<App />, "/");
  expect(screen.getByText("Get started")).toBeInTheDocument();
  await user.selectOptions(screen.getByLabelText("Language"), "pt-BR");
  expect(screen.getByText("Começar")).toBeInTheDocument();
  expect(window.localStorage.getItem("dottod-docs-locale")).toBe("pt-BR");
  expect(document.documentElement.lang).toBe("pt-BR");
});

test("unknown saved locale falls back to en-US", () => {
  cleanup();
  window.localStorage.clear();
  window.localStorage.setItem("dottod-docs-locale", "xx");
  harness(<App />, "/");
  expect(screen.getByText("Get started")).toBeInTheDocument();
});

test("theme toggle flips dark class and persists", async () => {
  cleanup();
  const user = userEvent.setup();
  window.localStorage.clear();
  harness(<App />, "/");
  expect(document.documentElement.classList.contains("dark")).toBe(true);
  await user.click(screen.getByLabelText("Theme"));
  expect(document.documentElement.classList.contains("dark")).toBe(false);
  expect(window.localStorage.getItem("dottod-docs-theme")).toBe("light");
});
