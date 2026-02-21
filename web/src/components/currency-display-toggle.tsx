"use client";

import { cn } from "@/lib/utils";
import { useCurrency } from "@/contexts/currency-context";

export type CurrencyDisplayMode = "base" | "native";

interface CurrencyDisplayToggleProps {
  mode: CurrencyDisplayMode;
  onModeChange: (mode: CurrencyDisplayMode) => void;
  className?: string;
}

export function CurrencyDisplayToggle({
  mode,
  onModeChange,
  className,
}: CurrencyDisplayToggleProps) {
  const { baseCurrency } = useCurrency();

  return (
    <div
      className={cn(
        "inline-flex items-center border border-border bg-card p-0.5 text-xs",
        className,
      )}
      role="group"
      aria-label="Mode d'affichage des montants"
    >
      <button
        type="button"
        onClick={() => onModeChange("base")}
        className={cn(
          "px-2 py-1 font-medium transition-colors",
          mode === "base" ? "bg-primary text-primary-foreground" : "text-muted-foreground",
        )}
      >
        {baseCurrency}
      </button>
      <button
        type="button"
        onClick={() => onModeChange("native")}
        className={cn(
          "px-2 py-1 font-medium transition-colors",
          mode === "native"
            ? "bg-primary text-primary-foreground"
            : "text-muted-foreground",
        )}
      >
        Native
      </button>
    </div>
  );
}
