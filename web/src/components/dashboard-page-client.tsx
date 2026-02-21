"use client";

import Link from "next/link";
import { useMemo, useState } from "react";
import { DashboardCharts } from "@/components/dashboard-charts";
import {
  CurrencyDisplayToggle,
  type CurrencyDisplayMode,
} from "@/components/currency-display-toggle";
import { useCurrency } from "@/contexts/currency-context";
import { convertAmountValue } from "@/hooks/use-converted-amount";
import { formatAmount } from "@/lib/format";
import { BANK_LABELS } from "@/lib/account-metadata";
import type {
  DashboardSummary,
  DashboardSpending,
  DashboardTrends,
  DashboardTopExpenses,
  AccountType,
} from "@/types";

function formatDate(iso: string): string {
  return new Intl.DateTimeFormat("fr-FR", {
    day: "numeric",
    month: "short",
    year: "numeric",
  }).format(new Date(iso));
}

const ACCOUNT_TYPE_ICONS: Record<AccountType, { icon: string; color: string }> = {
  checking: { icon: "🏦", color: "border-l-blue-500" },
  savings: { icon: "🐖", color: "border-l-emerald-500" },
  brokerage: { icon: "📈", color: "border-l-purple-500" },
  crypto: { icon: "₿", color: "border-l-amber-500" },
};

const ACCOUNT_TYPE_LABELS: Record<AccountType, string> = {
  checking: "Courant",
  savings: "Épargne",
  brokerage: "Bourse",
  crypto: "Crypto",
};

interface DashboardPageClientProps {
  month: string;
  summary: DashboardSummary;
  spending: DashboardSpending | null;
  trends: DashboardTrends | null;
  topExpenses: DashboardTopExpenses | null;
}

export function DashboardPageClient({
  month,
  summary,
  spending,
  trends,
  topExpenses,
}: DashboardPageClientProps) {
  const { baseCurrency, rates } = useCurrency();
  const [displayMode, setDisplayMode] = useState<CurrencyDisplayMode>("base");

  const accountCurrencies = useMemo(
    () => Array.from(new Set(summary.accounts.map((account) => account.currency))),
    [summary.accounts],
  );
  const assumedCurrency = accountCurrencies[0] ?? baseCurrency;
  const isSingleCurrency = accountCurrencies.length <= 1;

  const netWorthDisplay = useMemo(() => {
    if (displayMode === "base") {
      const total = summary.accounts.reduce((acc, account) => {
        const converted = convertAmountValue(
          account.balance,
          account.currency,
          baseCurrency,
          rates,
        );
        const value = converted ?? (parseFloat(account.balance) || 0);
        return acc + value;
      }, 0);
      return formatAmount(String(total), baseCurrency);
    }

    if (!isSingleCurrency) return null;
    const total = summary.accounts.reduce(
      (acc, account) => acc + (parseFloat(account.balance) || 0),
      0,
    );
    return formatAmount(String(total), assumedCurrency);
  }, [
    displayMode,
    summary.accounts,
    baseCurrency,
    rates,
    isSingleCurrency,
    assumedCurrency,
  ]);

  const changeVsLastMonth = (() => {
    if (!trends || trends.months.length < 2) return null;
    const lastMonth = trends.months[1];
    if (!lastMonth) return null;
    const net = parseFloat(lastMonth.net);
    if (net === 0) return null;
    if (displayMode === "base") {
      const converted = convertAmountValue(
        String(net),
        assumedCurrency,
        baseCurrency,
        rates,
      );
      return formatAmount(String(converted ?? net), baseCurrency);
    }
    return formatAmount(String(net), assumedCurrency);
  })();

  return (
    <div className="space-y-8">
      <div className="flex items-start justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold tracking-tight">Tableau de bord</h1>
          <p className="text-sm text-muted-foreground">Vue d&apos;ensemble de vos finances</p>
        </div>
        <CurrencyDisplayToggle mode={displayMode} onModeChange={setDisplayMode} />
      </div>

      <div className="border border-border bg-card p-6">
        <p className="text-sm font-medium text-muted-foreground">Patrimoine net</p>
        <div className="mt-1 flex items-baseline gap-3">
          <p className="text-3xl font-bold tracking-tight">{netWorthDisplay ?? "—"}</p>
          {changeVsLastMonth && (
            <span
              className={`text-sm font-medium ${
                changeVsLastMonth.startsWith("-") ? "text-danger" : "text-success"
              }`}
            >
              {!changeVsLastMonth.startsWith("-") ? "+" : ""}
              {changeVsLastMonth}{" "}
              <span className="text-muted-foreground">le mois dernier</span>
            </span>
          )}
        </div>
        <p className="mt-1 text-xs text-muted-foreground">
          {displayMode === "base"
            ? `Affiché en ${baseCurrency}`
            : isSingleCurrency
              ? `Affiché en ${assumedCurrency}`
              : "Mode natif indisponible en multi-devise"}
        </p>
        <p className="mt-1 text-xs text-muted-foreground">
          Estimation: les comptes crypto restent approximatifs.
        </p>
      </div>

      <section>
        <h2 className="mb-4 text-lg font-semibold">Comptes</h2>
        <div className="flex gap-4 overflow-x-auto pb-2">
          {summary.accounts.map((account) => {
            const typeInfo = ACCOUNT_TYPE_ICONS[account.type];
            return (
              <Link
                key={account.id}
                href={`/accounts/${account.id}`}
                className={`flex min-w-[220px] flex-col border border-border bg-card p-4 transition-colors hover:bg-accent border-l-4 ${typeInfo.color}`}
              >
                <div className="flex items-center gap-2">
                  <span className="text-lg">{typeInfo.icon}</span>
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-sm font-semibold">{account.name}</p>
                    <p className="truncate text-xs text-muted-foreground">
                      {BANK_LABELS[account.bank] ?? account.bank}
                    </p>
                  </div>
                </div>
                <p className="mt-3 text-lg font-bold tracking-tight">
                  {displayMode === "base" ? (
                    formatAmount(
                      String(
                        convertAmountValue(
                          account.balance,
                          account.currency,
                          baseCurrency,
                          rates,
                        ) ??
                          (parseFloat(account.balance) || 0),
                      ),
                      baseCurrency,
                    )
                  ) : (
                    formatAmount(account.balance, account.currency)
                  )}
                </p>
                <div className="mt-1 flex items-center justify-between">
                  <span className="text-xs text-muted-foreground">
                    {ACCOUNT_TYPE_LABELS[account.type]}
                  </span>
                  {account.last_import_at && (
                    <span className="text-xs text-muted-foreground">
                      {formatDate(account.last_import_at)}
                    </span>
                  )}
                </div>
              </Link>
            );
          })}
        </div>
      </section>

      <DashboardCharts
        month={month}
        spending={spending}
        trends={trends}
        topExpenses={topExpenses}
        displayMode={displayMode}
        assumedCurrency={assumedCurrency}
      />
    </div>
  );
}
