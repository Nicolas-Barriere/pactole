"use client";

import { useMemo } from "react";
import { useCurrency } from "@/contexts/currency-context";
import { formatAmount } from "@/lib/format";

export function convertAmount(
  amount: string,
  fromCurrency: string,
  baseCurrency: string,
  rates: Record<string, number>,
): string {
  if (fromCurrency === baseCurrency) {
    return formatAmount(amount, fromCurrency);
  }

  const baseRate = rates[baseCurrency];
  const fromRate = rates[fromCurrency];
  const parsed = parseFloat(amount);

  if (
    !Number.isFinite(parsed) ||
    !Number.isFinite(baseRate) ||
    !Number.isFinite(fromRate) ||
    fromRate <= 0
  ) {
    return formatAmount(amount, fromCurrency);
  }

  const converted = (parsed * baseRate) / fromRate;
  return formatAmount(String(converted), baseCurrency);
}

export function useConvertedAmount(amount: string, fromCurrency: string): string {
  const { baseCurrency, rates } = useCurrency();

  return useMemo(
    () => convertAmount(amount, fromCurrency, baseCurrency, rates),
    [amount, fromCurrency, baseCurrency, rates],
  );
}
