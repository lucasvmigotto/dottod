import { render } from "@testing-library/react";
import type { ReactNode } from "react";
import { I18nProvider } from "../../src/i18n/index";

export function harness(ui: ReactNode, route = "/") {
  window.location.hash = `#${route}`;
  return render(<I18nProvider>{ui}</I18nProvider>);
}

export function appRoutes() {
  return [
    "/",
    "/start",
    "/tasks",
    "/commands",
    "/config",
    "/concepts",
    "/architecture",
    "/roadmap",
  ];
}
