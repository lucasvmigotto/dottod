import { expect, test } from "@playwright/test";

test("overview renders the transcript hero", async ({ page }) => {
  await page.goto("/dottod/#/");
  await expect(page.getByLabel("terminal transcript")).toBeVisible();
  await expect(page.getByRole("link", { name: "Get started" })).toBeVisible();
});

test("deep link to a task page works", async ({ page }) => {
  await page.goto("/dottod/#/tasks/neovim");
  await expect(page.getByRole("heading", { name: "neovim" })).toBeVisible();
});

test("keyboard-only: skip link, search, language", async ({ page }) => {
  await page.goto("/dottod/#/");
  await page.keyboard.press("Tab");
  await expect(page.getByText("Skip to content")).toBeFocused();
  await page.keyboard.press("/");
  await expect(page.getByPlaceholder("Search pages…")).toBeFocused();
  await page.keyboard.type("neovim");
  await page.keyboard.press("Enter");
});

test("language switch persists and sets html lang", async ({ page }) => {
  await page.goto("/dottod/#/");
  await page.selectOption("#lang-select", "pt-BR");
  await expect(page.locator("html")).toHaveAttribute("lang", "pt-BR");
  await expect(page.getByText("Começar")).toBeVisible();
  await page.reload();
  await expect(page.getByText("Começar")).toBeVisible();
});

test("mobile project keeps nav reachable", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto("/dottod/#/tasks");
  await page.getByRole("button", { name: "Menu" }).click();
  await expect(page.getByRole("link", { name: "Commands" })).toBeVisible();
});
