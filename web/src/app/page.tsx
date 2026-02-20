"use client";

import { useEffect, useState, useCallback, useMemo } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { dashboard } from "@/lib/api";
import type { TooltipContentProps } from "recharts";
import { Skeleton, SkeletonCard, SkeletonChart } from "@/components/skeleton";
import type {
  DashboardSummary,
  DashboardSpending,
  DashboardTrends,
  DashboardTopExpenses,
  AccountType,
} from "@/types";
import {
  PieChart,
  Pie,
  Cell,
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  Legend,
} from "recharts";

/* ── Helpers ─────────────────────────────────────────── */

function formatAmount(amount: string, currency = "EUR"): string {
  return new Intl.NumberFormat("fr-FR", {
    style: "currency",
    currency,
  }).format(parseFloat(amount));
}

function formatDate(iso: string): string {
  return new Intl.DateTimeFormat("fr-FR", {
    day: "numeric",
    month: "short",
    year: "numeric",
  }).format(new Date(iso));
}

function formatMonthLabel(month: string): string {
  const [year, m] = month.split("-");
  const date = new Date(parseInt(year), parseInt(m) - 1, 1);
  return date.toLocaleDateString("fr-FR", { month: "long", year: "numeric" });
}

function formatShortMonth(month: string): string {
  const [year, m] = month.split("-");
  const date = new Date(parseInt(year), parseInt(m) - 1, 1);
  return date.toLocaleDateString("fr-FR", { month: "short" });
}

function currentMonthStr(): string {
  const now = new Date();
  const m = String(now.getMonth() + 1).padStart(2, "0");
  return `${now.getFullYear()}-${m}`;
}

function shiftMonth(month: string, offset: number): string {
  const [year, m] = month.split("-").map(Number);
  const total = year * 12 + (m - 1) + offset;
  const newYear = Math.floor(total / 12);
  const newMonth = (total % 12) + 1;
  return `${newYear}-${String(newMonth).padStart(2, "0")}`;
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

/* ── Dashboard Page ──────────────────────────────────── */

export default function DashboardPage() {
  const [month, setMonth] = useState(currentMonthStr);
  const [summary, setSummary] = useState<DashboardSummary | null>(null);
  const [spending, setSpending] = useState<DashboardSpending | null>(null);
  const [trends, setTrends] = useState<DashboardTrends | null>(null);
  const [topExpenses, setTopExpenses] = useState<DashboardTopExpenses | null>(null);
  const [loading, setLoading] = useState(true);
  const [monthLoading, setMonthLoading] = useState(false);

  const fetchMonthData = useCallback(async (m: string) => {
    const [sp, te] = await Promise.all([
      dashboard.spending(m),
      dashboard.topExpenses(m),
    ]);
    setSpending(sp);
    setTopExpenses(te);
  }, []);

  const fetchDashboard = useCallback(async () => {
    try {
      const [s, t] = await Promise.all([
        dashboard.summary(),
        dashboard.trends(12),
      ]);
      setSummary(s);
      setTrends(t);
      await fetchMonthData(currentMonthStr());
    } finally {
      setLoading(false);
    }
  }, [fetchMonthData]);

  useEffect(() => {
    fetchDashboard();
  }, [fetchDashboard]);

  const handleMonthChange = useCallback(
    (offset: number) => {
      const newMonth = shiftMonth(month, offset);
      setMonth(newMonth);
      setMonthLoading(true);
      fetchMonthData(newMonth).finally(() => setMonthLoading(false));
    },
    [month, fetchMonthData],
  );

  const isEmpty = summary && summary.accounts.length === 0;

  if (loading) return <DashboardSkeleton />;
  if (isEmpty) return <EmptyState />;

  return (
    <div className="space-y-8">
      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold tracking-tight">Tableau de bord</h1>
        <p className="text-sm text-muted">
          Vue d&apos;ensemble de vos finances
        </p>
      </div>

      {/* Net Worth */}
      {summary && <NetWorthHeader summary={summary} trends={trends} />}

      {/* Account Cards */}
      {summary && <AccountCards summary={summary} />}

      {/* Month Selector */}
      <MonthSelector
        month={month}
        onPrev={() => handleMonthChange(-1)}
        onNext={() => handleMonthChange(1)}
      />

      {/* Charts Row */}
      <div className="grid gap-6 lg:grid-cols-2">
        <SpendingBreakdown
          spending={spending}
          loading={monthLoading}
          month={month}
        />
        <TrendsChart trends={trends} />
      </div>

      {/* Top Expenses */}
      <TopExpensesList
        topExpenses={topExpenses}
        loading={monthLoading}
      />
    </div>
  );
}

/* ── Net Worth Header ────────────────────────────────── */

function NetWorthHeader({
  summary,
  trends,
}: {
  summary: DashboardSummary;
  trends: DashboardTrends | null;
}) {
  const changeVsLastMonth = useMemo(() => {
    if (!trends || trends.months.length < 2) return null;
    const lastMonth = trends.months[1];
    if (!lastMonth) return null;
    const net = parseFloat(lastMonth.net);
    if (net === 0) return null;
    return net;
  }, [trends]);

  return (
    <div className="rounded-xl border border-border bg-card p-6">
      <p className="text-sm font-medium text-muted">Patrimoine net</p>
      <div className="mt-1 flex items-baseline gap-3">
        <p className="text-3xl font-bold tracking-tight">
          {formatAmount(summary.net_worth, summary.currency)}
        </p>
        {changeVsLastMonth !== null && (
          <span
            className={`text-sm font-medium ${
              changeVsLastMonth >= 0 ? "text-success" : "text-danger"
            }`}
          >
            {changeVsLastMonth >= 0 ? "+" : ""}
            {formatAmount(String(changeVsLastMonth), summary.currency)}{" "}
            <span className="text-muted">le mois dernier</span>
          </span>
        )}
      </div>
      <p className="mt-1 text-xs text-muted">{summary.currency}</p>
    </div>
  );
}

/* ── Account Cards ───────────────────────────────────── */

function AccountCards({ summary }: { summary: DashboardSummary }) {
  return (
    <section>
      <h2 className="mb-4 text-lg font-semibold">Comptes</h2>
      <div className="flex gap-4 overflow-x-auto pb-2">
        {summary.accounts.map((account) => {
          const typeInfo = ACCOUNT_TYPE_ICONS[account.type];
          return (
            <Link
              key={account.id}
              href={`/accounts/${account.id}`}
              className={`flex min-w-[220px] flex-col rounded-xl border border-border bg-card p-4 transition-colors hover:bg-card-hover border-l-4 ${typeInfo.color}`}
            >
              <div className="flex items-center gap-2">
                <span className="text-lg">{typeInfo.icon}</span>
                <div className="min-w-0 flex-1">
                  <p className="truncate text-sm font-semibold">
                    {account.name}
                  </p>
                  <p className="truncate text-xs text-muted">{account.bank}</p>
                </div>
              </div>
              <p className="mt-3 text-lg font-bold tracking-tight">
                {formatAmount(account.balance)}
              </p>
              <div className="mt-1 flex items-center justify-between">
                <span className="text-xs text-muted">
                  {ACCOUNT_TYPE_LABELS[account.type]}
                </span>
                {account.last_import_at && (
                  <span className="text-xs text-muted">
                    {formatDate(account.last_import_at)}
                  </span>
                )}
              </div>
            </Link>
          );
        })}
      </div>
    </section>
  );
}

/* ── Month Selector ──────────────────────────────────── */

function MonthSelector({
  month,
  onPrev,
  onNext,
}: {
  month: string;
  onPrev: () => void;
  onNext: () => void;
}) {
  const isCurrentMonth = month === currentMonthStr();

  return (
    <div className="flex items-center justify-center gap-4">
      <button
        onClick={onPrev}
        className="rounded-lg p-2 text-muted transition-colors hover:bg-card hover:text-foreground"
        aria-label="Mois précédent"
      >
        <ChevronLeftIcon className="h-5 w-5" />
      </button>
      <span className="min-w-[200px] text-center text-lg font-semibold capitalize">
        {formatMonthLabel(month)}
      </span>
      <button
        onClick={onNext}
        disabled={isCurrentMonth}
        className="rounded-lg p-2 text-muted transition-colors hover:bg-card hover:text-foreground disabled:opacity-30 disabled:cursor-not-allowed"
        aria-label="Mois suivant"
      >
        <ChevronRightIcon className="h-5 w-5" />
      </button>
    </div>
  );
}

/* ── Spending Breakdown (Pie Chart) ──────────────────── */

function SpendingBreakdown({
  spending,
  loading,
  month,
}: {
  spending: DashboardSpending | null;
  loading: boolean;
  month: string;
}) {
  const router = useRouter();

  if (loading || !spending) {
    return (
      <div className="rounded-xl border border-border bg-card p-6">
        <Skeleton className="mb-6 h-4 w-40" />
        <div className="flex h-64 items-center justify-center">
          <Skeleton className="h-48 w-48 rounded-full" />
        </div>
      </div>
    );
  }

  const data = spending.by_tag.map((t) => ({
    name: t.tag,
    value: Math.abs(parseFloat(t.amount)),
    color: t.color,
    percentage: t.percentage,
  }));

  const hasData = data.length > 0;

  return (
    <div className="rounded-xl border border-border bg-card p-6">
      <h3 className="mb-1 text-sm font-semibold text-muted">
        Dépenses par tag
      </h3>
      <p className="mb-4 text-xs text-muted">
        Total :{" "}
        <span className="font-medium text-danger">
          {formatAmount(spending.total_expenses)}
        </span>
      </p>

      {!hasData ? (
        <div className="flex h-48 items-center justify-center text-sm text-muted">
          Aucune dépense ce mois
        </div>
      ) : (
        <div className="flex flex-col items-center gap-4 lg:flex-row">
          <div className="h-56 w-56 shrink-0">
            <ResponsiveContainer width="100%" height="100%">
              <PieChart>
                <Pie
                  data={data}
                  dataKey="value"
                  nameKey="name"
                  cx="50%"
                  cy="50%"
                  innerRadius={50}
                  outerRadius={90}
                  paddingAngle={2}
                  strokeWidth={0}
                  cursor="pointer"
                  onClick={(entry) => {
                    const tag = entry?.name;
                    if (tag && tag !== "Untagged") {
                      router.push(
                        `/transactions?tag=${encodeURIComponent(tag)}&month=${month}`,
                      );
                    }
                  }}
                >
                  {data.map((entry, i) => (
                    <Cell key={i} fill={entry.color} />
                  ))}
                </Pie>
                <Tooltip
                  content={<SpendingTooltip />}
                  wrapperStyle={{ outline: "none" }}
                />
              </PieChart>
            </ResponsiveContainer>
          </div>

          <div className="flex-1 space-y-2">
            {data.map((entry, i) => (
              <div key={i} className="flex items-center gap-2 text-sm">
                <span
                  className="inline-block h-3 w-3 shrink-0 rounded-sm"
                  style={{ backgroundColor: entry.color }}
                />
                <span className="flex-1 truncate">{entry.name}</span>
                <span className="font-medium tabular-nums">
                  {formatAmount(String(-entry.value))}
                </span>
                <span className="w-12 text-right text-xs text-muted tabular-nums">
                  {entry.percentage}%
                </span>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

function SpendingTooltip({ active, payload }: Partial<TooltipContentProps<number, string>>) {
  if (!active || !payload?.[0]) return null;
  const data = payload[0].payload as { name: string; value: number; percentage: number };
  return (
    <div className="rounded-lg border border-border bg-card px-3 py-2 text-sm shadow-lg">
      <p className="font-medium">{data.name}</p>
      <p className="text-muted">
        {formatAmount(String(-data.value))} ({data.percentage}%)
      </p>
    </div>
  );
}

/* ── Trends Chart (Bar Chart) ────────────────────────── */

function TrendsChart({ trends }: { trends: DashboardTrends | null }) {
  if (!trends) {
    return <SkeletonChart />;
  }

  const data = [...trends.months]
    .reverse()
    .map((m) => ({
      month: formatShortMonth(m.month),
      Revenus: parseFloat(m.income),
      Dépenses: Math.abs(parseFloat(m.expenses)),
    }));

  const hasData = data.some((d) => d.Revenus > 0 || d.Dépenses > 0);

  return (
    <div className="rounded-xl border border-border bg-card p-6">
      <h3 className="mb-4 text-sm font-semibold text-muted">
        Revenus vs Dépenses
      </h3>

      {!hasData ? (
        <div className="flex h-48 items-center justify-center text-sm text-muted">
          Aucune donnée disponible
        </div>
      ) : (
        <div className="h-64">
          <ResponsiveContainer width="100%" height="100%">
            <BarChart data={data} barGap={2}>
              <CartesianGrid
                strokeDasharray="3 3"
                vertical={false}
                stroke="var(--color-border)"
              />
              <XAxis
                dataKey="month"
                axisLine={false}
                tickLine={false}
                tick={{ fill: "var(--color-muted)", fontSize: 12 }}
              />
              <YAxis
                axisLine={false}
                tickLine={false}
                tick={{ fill: "var(--color-muted)", fontSize: 12 }}
                tickFormatter={(v) =>
                  v >= 1000 ? `${(v / 1000).toFixed(0)}k` : String(v)
                }
              />
              <Tooltip
                content={<TrendTooltip />}
                wrapperStyle={{ outline: "none" }}
                cursor={{ fill: "rgba(255,255,255,0.03)" }}
              />
              <Legend
                iconType="square"
                iconSize={10}
                wrapperStyle={{ fontSize: 12, color: "var(--color-muted)" }}
              />
              <Bar
                dataKey="Revenus"
                fill="var(--color-success)"
                radius={[4, 4, 0, 0]}
                maxBarSize={32}
              />
              <Bar
                dataKey="Dépenses"
                fill="var(--color-danger)"
                radius={[4, 4, 0, 0]}
                maxBarSize={32}
              />
            </BarChart>
          </ResponsiveContainer>
        </div>
      )}
    </div>
  );
}

function TrendTooltip({ active, payload, label }: Partial<TooltipContentProps<number, string>>) {
  if (!active || !payload?.length) return null;
  return (
    <div className="rounded-lg border border-border bg-card px-3 py-2 text-sm shadow-lg">
      <p className="mb-1 font-medium capitalize">{label}</p>
      {payload.map((entry: { dataKey?: string; color?: string; value?: number }) => (
        <p key={entry.dataKey} style={{ color: entry.color }}>
          {entry.dataKey} : {formatAmount(String(entry.value))}
        </p>
      ))}
    </div>
  );
}

/* ── Top 5 Expenses ──────────────────────────────────── */

function TopExpensesList({
  topExpenses,
  loading,
}: {
  topExpenses: DashboardTopExpenses | null;
  loading: boolean;
}) {
  if (loading || !topExpenses) {
    return (
      <section>
        <Skeleton className="mb-4 h-5 w-40" />
        <div className="space-y-2">
          {Array.from({ length: 5 }).map((_, i) => (
            <Skeleton key={i} className="h-12 w-full rounded-lg" />
          ))}
        </div>
      </section>
    );
  }

  const { expenses } = topExpenses;

  return (
    <section>
      <h2 className="mb-4 text-lg font-semibold">Top 5 dépenses</h2>
      {expenses.length === 0 ? (
        <div className="rounded-xl border border-dashed border-border bg-card p-6 text-center text-sm text-muted">
          Aucune dépense ce mois
        </div>
      ) : (
        <div className="rounded-xl border border-border bg-card divide-y divide-border">
          {expenses.map((expense) => (
            <div
              key={expense.id}
              className="flex items-center gap-4 px-5 py-3"
            >
              <span className="shrink-0 text-xs text-muted tabular-nums">
                {formatDate(expense.date)}
              </span>
              <span className="min-w-0 flex-1 truncate text-sm">
                {expense.label}
              </span>
              <span className="inline-flex flex-wrap gap-1">
                {expense.tags.length > 0 ? expense.tags.map((tag) => (
                  <span key={tag} className="inline-flex items-center rounded-full bg-card-hover px-2 py-0.5 text-xs text-muted">
                    {tag}
                  </span>
                )) : (
                  <span className="text-xs text-muted/50">—</span>
                )}
              </span>
              <span className="text-xs text-muted">{expense.account}</span>
              <span className="shrink-0 text-sm font-semibold text-danger tabular-nums">
                {formatAmount(expense.amount)}
              </span>
            </div>
          ))}
        </div>
      )}
    </section>
  );
}

/* ── Empty State ─────────────────────────────────────── */

function EmptyState() {
  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-2xl font-bold tracking-tight">Tableau de bord</h1>
        <p className="text-sm text-muted">
          Vue d&apos;ensemble de vos finances
        </p>
      </div>

      <div className="flex flex-col items-center justify-center rounded-xl border border-dashed border-border bg-card px-6 py-16 text-center">
        <div className="mb-4 text-5xl">📊</div>
        <h2 className="mb-2 text-xl font-semibold">
          Bienvenue sur Moulax
        </h2>
        <p className="mb-6 max-w-md text-sm text-muted">
          Commencez par créer un compte bancaire puis importez votre premier
          relevé CSV pour voir votre tableau de bord prendre vie.
        </p>
        <div className="flex gap-3">
          <Link
            href="/accounts"
            className="rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white transition-colors hover:bg-primary-hover"
          >
            Créer un compte
          </Link>
          <Link
            href="/import"
            className="rounded-lg border border-border bg-card px-4 py-2 text-sm font-medium transition-colors hover:bg-card-hover"
          >
            Importer un relevé
          </Link>
        </div>
      </div>
    </div>
  );
}

/* ── Loading Skeleton ────────────────────────────────── */

function DashboardSkeleton() {
  return (
    <div className="space-y-8">
      <div>
        <Skeleton className="mb-2 h-7 w-48" />
        <Skeleton className="h-4 w-64" />
      </div>

      <SkeletonCard />

      <div className="flex gap-4 overflow-hidden">
        {Array.from({ length: 3 }).map((_, i) => (
          <div
            key={i}
            className="min-w-[220px] rounded-xl border border-border bg-card p-4"
          >
            <Skeleton className="mb-2 h-4 w-24" />
            <Skeleton className="mb-3 h-3 w-16" />
            <Skeleton className="h-6 w-32" />
          </div>
        ))}
      </div>

      <div className="flex justify-center">
        <Skeleton className="h-8 w-56" />
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        <SkeletonChart />
        <SkeletonChart />
      </div>

      <div>
        <Skeleton className="mb-4 h-5 w-40" />
        <div className="space-y-2">
          {Array.from({ length: 5 }).map((_, i) => (
            <Skeleton key={i} className="h-12 w-full rounded-lg" />
          ))}
        </div>
      </div>
    </div>
  );
}

/* ── Icons ───────────────────────────────────────────── */

function ChevronLeftIcon({ className }: { className?: string }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M15.75 19.5 8.25 12l7.5-7.5" />
    </svg>
  );
}

function ChevronRightIcon({ className }: { className?: string }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
      <path strokeLinecap="round" strokeLinejoin="round" d="m8.25 4.5 7.5 7.5-7.5 7.5" />
    </svg>
  );
}
