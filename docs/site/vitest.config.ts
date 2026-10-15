import { defineConfig } from "vitest/config";

export default defineConfig({
  define: {
    __APP_VERSION__: JSON.stringify("0.0.0-test"),
    __SITE_URL__: JSON.stringify("http://localhost/"),
    __VERSIONS__: JSON.stringify([
      {
        name: "dottod",
        version: "1.8.0",
        label: "dottod@v1.8.0",
        href: "https://github.com/lucasvmigotto/dottod/tree/1.8.0",
      },
      {
        name: "docs",
        version: "0.1.0",
        label: "docs@v0.1.0",
        href: "https://github.com/lucasvmigotto/dottod/tree/1.8.0/docs/site",
      },
    ]),
  },
  test: {
    environment: "jsdom",
    setupFiles: ["./tests/setup.ts"],
    include: ["tests/unit/**/*.test.{ts,tsx}", "tests/a11y/**/*.test.{tsx}"],
  },
});
