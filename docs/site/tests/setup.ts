import "@testing-library/jest-dom/vitest";
import { cleanup } from "@testing-library/react";
import * as matchers from "vitest-axe/matchers";
import "vitest-axe/extend-expect";
import { afterEach } from "vitest";

void matchers;

// RTL's auto-cleanup relies on globals wiring that proved flaky here
// (mounted roots outliving jsdom teardown crashed the scheduler), so
// unmount explicitly after every test.
afterEach(() => {
  cleanup();
});
