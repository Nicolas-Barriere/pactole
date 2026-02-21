"use client";

import { useMemo } from "react";
import { useCurrency } from "@/contexts/currency-context";
import { formatAmount } from "@/lib/format";

export function convertAmountValue(
  amount: string,
  fromCurrency: string,
  baseCurrency: string,
  rates: Record<string, number>,
): number | null {
  const parsed = parseFloat(amount);
  if (!Number.isFinite(parsed)) {
    return null;
  }

  if (fromCurrency === baseCurrency) {
    return parsed;
  }

  const baseRate = rates[baseCurrency];
  const fromRate = rates[fromCurrency];
  if (!Number.isFinite(baseRate) || !Number.isFinite(fromRate) || fromRate <= 0) {
    return null;
  }

  return (parsed * baseRate) / fromRate;
}

export function convertAmount(
  amount: string,
  fromCurrency: string,
  baseCurrency: string,
  rates: Record<string, number>,
): string {
  const converted = convertAmountValue(amount, fromCurrency, baseCurrency, rates);
  if (converted === null) {
    return formatAmount(amount, fromCurrency);
  }
  return formatAmount(String(converted), baseCurrency);
}

export function useConvertedAmount(amount: string, fromCurrency: string): string {
  const { baseCurrency, rates } = useCurrency();

  return useMemo(
    () => convertAmount(amount, fromCurrency, baseCurrency, rates),
    [amount, fromCurrency, baseCurrency, rates],
  );
}
