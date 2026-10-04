import type { ReactNode } from "react";
import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
} from "react";
import { enUS } from "./locales/en-US";
import { ptBR } from "./locales/pt-BR";
import {
  DEFAULT_LOCALE,
  type DocsContent,
  LOCALES,
  type Locale,
} from "./types";

const BUNDLES: Record<Locale, DocsContent> = { "en-US": enUS, "pt-BR": ptBR };
const STORAGE_KEY = "dottod-docs-locale";
const THEME_KEY = "dottod-docs-theme";

export type Theme = "dark" | "light";

function detectLocale(): Locale {
  try {
    const saved = localStorage.getItem(STORAGE_KEY);
    if (saved === "pt-BR" || saved === "en-US") return saved;
  } catch {
    // storage unavailable: fall through to detection
  }
  const nav = typeof navigator !== "undefined" ? navigator.language : "";
  if (nav.toLowerCase().startsWith("pt")) return "pt-BR";
  return DEFAULT_LOCALE;
}

function detectTheme(): Theme {
  try {
    const saved = localStorage.getItem(THEME_KEY);
    if (saved === "light" || saved === "dark") return saved;
  } catch {
    // ignore
  }
  return "dark";
}

interface I18n {
  locale: Locale;
  setLocale: (l: Locale) => void;
  content: DocsContent;
  theme: Theme;
  toggleTheme: () => void;
}

const Ctx = createContext<I18n | null>(null);

export function I18nProvider({ children }: { children: ReactNode }) {
  const [locale, setLocaleState] = useState<Locale>(detectLocale);
  const [theme, setTheme] = useState<Theme>(detectTheme);

  useEffect(() => {
    document.documentElement.lang = locale;
    try {
      localStorage.setItem(STORAGE_KEY, locale);
    } catch {
      // ignore
    }
  }, [locale]);

  useEffect(() => {
    document.documentElement.classList.toggle("dark", theme === "dark");
    document.documentElement.style.colorScheme = theme;
    try {
      localStorage.setItem(THEME_KEY, theme);
    } catch {
      // ignore
    }
  }, [theme]);

  const setLocale = useCallback((l: Locale) => {
    if (LOCALES.includes(l)) setLocaleState(l);
  }, []);

  const toggleTheme = useCallback(() => {
    setTheme((t) => (t === "dark" ? "light" : "dark"));
  }, []);

  const value = useMemo<I18n>(
    () => ({ locale, setLocale, content: BUNDLES[locale], theme, toggleTheme }),
    [locale, setLocale, theme, toggleTheme],
  );
  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

export function useI18n(): I18n {
  const ctx = useContext(Ctx);
  if (!ctx) throw new Error("useI18n must be used inside I18nProvider");
  return ctx;
}
