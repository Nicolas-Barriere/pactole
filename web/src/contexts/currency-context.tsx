"use client";

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useState,
  useMemo,
  type ReactNode,
} from "react";
import { currencies, exchangeRates } from "@/lib/api";
import { CURRENCIES, type CurrencyCode } from "@/types";

const STORAGE_KEY = "pactole_base_currency";
const DEFAULT_BASE_CURRENCY: CurrencyCode = "EUR";
const STALE_AFTER_HOURS = 24;

type RatesMap = Record<string, number>;

interface CurrencyContextValue {
  baseCurrency: CurrencyCode;
  setBaseCurrency: (currency: CurrencyCode) => void;
  rates: RatesMap;
  ratesUpdatedAt: string | null;
  refreshRates: () => Promise<void>;
  supportedCurrencies: CurrencyCode[];
  isRatesStale: boolean;
}

const CurrencyContext = createContext<CurrencyContextValue | null>(null);

function isCurrencyCode(value: string): value is CurrencyCode {
  return (CURRENCIES as readonly string[]).includes(value);
}

export function CurrencyProvider({ children }: { children: ReactNode }) {
  const [baseCurrency, setBaseCurrencyState] = useState<CurrencyCode>(() => {
    if (typeof window === "undefined") return DEFAULT_BASE_CURRENCY;
    const raw = window.localStorage.getItem(STORAGE_KEY);
    return raw && isCurrencyCode(raw) ? raw : DEFAULT_BASE_CURRENCY;
  });
  const [rates, setRates] = useState<RatesMap>({ EUR: 1 });
  const [ratesUpdatedAt, setRatesUpdatedAt] = useState<string | null>(null);
  const [supportedCurrencies, setSupportedCurrencies] = useState<CurrencyCode[]>(
    [DEFAULT_BASE_CURRENCY],
  );
  const [isRatesStale, setIsRatesStale] = useState(true);

  const setBaseCurrency = useCallback((currency: CurrencyCode) => {
    setBaseCurrencyState(currency);
  }, []);

  const refreshRates = useCallback(async () => {
    const data = await exchangeRates.list("EUR");
    const nextRates: RatesMap = { EUR: 1 };

    for (const [code, rawRate] of Object.entries(data.rates)) {
      const parsed = parseFloat(rawRate);
      if (Number.isFinite(parsed) && parsed > 0) {
        nextRates[code] = parsed;
      }
    }

    setRates(nextRates);
    setRatesUpdatedAt(data.fetched_at);
    const fetchedAt = data.fetched_at ? new Date(data.fetched_at).getTime() : NaN;
    const stale =
      Number.isNaN(fetchedAt) ||
      Date.now() - fetchedAt > STALE_AFTER_HOURS * 60 * 60 * 1000;
    setIsRatesStale(stale);
  }, []);

  useEffect(() => {
    window.localStorage.setItem(STORAGE_KEY, baseCurrency);
  }, [baseCurrency]);

  useEffect(() => {
    const timeout = window.setTimeout(() => {
      refreshRates().catch(() => {});
    }, 0);
    return () => window.clearTimeout(timeout);
  }, [refreshRates]);

  useEffect(() => {
    currencies
      .list()
      .then((data) => {
        const all = [...data.fiat, ...data.crypto].filter(isCurrencyCode);
        const unique = Array.from(new Set(all));
        if (unique.length > 0) {
          setSupportedCurrencies(unique);
          if (!unique.includes(baseCurrency)) {
            setBaseCurrencyState(DEFAULT_BASE_CURRENCY);
          }
        }
      })
      .catch(() => {});
  }, [baseCurrency]);

  const value = useMemo<CurrencyContextValue>(
    () => ({
      baseCurrency,
      setBaseCurrency,
      rates,
      ratesUpdatedAt,
      refreshRates,
      supportedCurrencies,
      isRatesStale,
    }),
    [
      baseCurrency,
      setBaseCurrency,
      rates,
      ratesUpdatedAt,
      refreshRates,
      supportedCurrencies,
      isRatesStale,
    ],
  );

  return (
    <CurrencyContext.Provider value={value}>{children}</CurrencyContext.Provider>
  );
}

export function useCurrency(): CurrencyContextValue {
  const ctx = useContext(CurrencyContext);
  if (!ctx) {
    throw new Error("useCurrency must be used within CurrencyProvider");
  }
  return ctx;
}
