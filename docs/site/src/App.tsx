import { useEffect } from "react";
import { Router } from "./app/router";
import { useI18n } from "./i18n/index";

export function App() {
  const { locale } = useI18n();
  useEffect(() => {
    document.title =
      locale === "pt-BR" ? "dottod — documentação" : "dottod — docs";
  }, [locale]);
  return <Router />;
}
