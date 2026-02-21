"use client";

import { cn } from "@/lib/utils";
import { useConvertedAmount } from "@/hooks/use-converted-amount";

interface TransactionAmountProps {
  amount: string;
  currency?: string;
  className?: string;
}

export function TransactionAmount({
  amount,
  currency = "EUR",
  className,
}: TransactionAmountProps) {
  const numericAmount = parseFloat(amount);
  const displayAmount = useConvertedAmount(amount, currency);
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
