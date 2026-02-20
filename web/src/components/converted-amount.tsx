"use client";

import { useCurrency } from "@/contexts/currency-context";
import { convertAmount } from "@/hooks/use-converted-amount";

export function ConvertedAmount({
  amount,
  fromCurrency,
}: {
  amount: string;
  fromCurrency: string;
}) {
  const { baseCurrency, rates } = useCurrency();
  return convertAmount(amount, fromCurrency, baseCurrency, rates);
}
