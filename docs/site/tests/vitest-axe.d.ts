// vitest-axe 0.1.0 augments the legacy global `Vi` namespace, which Vitest 3
// no longer consults. Declare the matcher on the `vitest` module instead.
import "vitest";

interface AxeMatchers {
  toHaveNoViolations(): void;
}

declare module "vitest" {
  interface Assertion<T = unknown> extends AxeMatchers {}
  interface AsymmetricMatchersContaining extends AxeMatchers {}
}
