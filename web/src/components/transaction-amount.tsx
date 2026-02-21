"use client";

import { cn } from "@/lib/utils";
import { formatAmount } from "@/lib/format";
import { useCurrency } from "@/contexts/currency-context";
import { convertAmount } from "@/hooks/use-converted-amount";
import type { CurrencyDisplayMode } from "@/components/currency-display-toggle";

interface TransactionAmountProps {
  amount: string;
  currency?: string;
  mode?: CurrencyDisplayMode;
  className?: string;
}

export function TransactionAmount({
  amount,
  currency = "EUR",
  mode = "base",
  className,
}: TransactionAmountProps) {
  const { baseCurrency, rates } = useCurrency();
  const numericAmount = parseFloat(amount);
  const displayAmount =
    mode === "base"
      ? convertAmount(amount, currency, baseCurrency, rates)
      : formatAmount(amount, currency);
  const amountColorClass =
    numericAmount > 0
      ? "text-emerald-600 dark:text-emerald-400"
      : numericAmount < 0
        ? "text-red-600 dark:text-red-400"
        : "text-foreground";

  return (
    <div
      className={cn(
        "block w-full whitespace-nowrap text-right font-medium tabular-nums",
        amountColorClass,
        className,
      )}
    >
      {numericAmount > 0 ? "+" : ""}
      {displayAmount}
    </div>
  );
}
