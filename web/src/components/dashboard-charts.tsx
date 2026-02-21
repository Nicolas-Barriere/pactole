"use client";

import { useRouter } from "next/navigation";
import type { TooltipContentProps } from "recharts";
import {
  PieChart,
  Pie,
  Cell,
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
} from "recharts";
import { ChevronLeft, ChevronRight } from "lucide-react";
import { Button } from "@/components/ui/button";
import { useCurrency } from "@/contexts/currency-context";
import { convertAmountValue } from "@/hooks/use-converted-amount";
import type { CurrencyDisplayMode } from "@/components/currency-display-toggle";
import {
  ChartContainer,
  ChartLegend,
  ChartLegendContent,
  ChartTooltip,
  ChartTooltipContent,
  type ChartConfig,
} from "@/components/ui/chart";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { formatAmount } from "@/lib/format";
import type {
  DashboardSpending,
  DashboardTrends,
  DashboardTopExpenses,
} from "@/types";

/* ── Helpers ─────────────────────────────────────────── */

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

function toNumber(value: unknown): number {
  if (typeof value === "number") return value;
  if (typeof value === "string") return Number(value) || 0;
  if (Array.isArray(value)) return toNumber(value[0]);
  return 0;
}

const spendingChartConfig = {
  value: { label: "Montant" },
} satisfies ChartConfig;

const trendsChartConfig = {
  income: {
    label: "Revenus",
    theme: {
      light: "oklch(0.72 0.18 154)",
      dark: "oklch(0.79 0.16 154)",
    },
  },
  expense: {
    label: "Dépenses",
    theme: {
      light: "oklch(0.66 0.21 28)",
      dark: "oklch(0.73 0.19 28)",
    },
  },
} satisfies ChartConfig;

const TAG_FALLBACK_COLORS = [
  "var(--chart-1)",
  "var(--chart-2)",
  "var(--chart-3)",
  "var(--chart-4)",
  "var(--chart-5)",
] as const;

const UNTAGGED_TAG_COLOR = "oklch(0.78 0.16 84)";

function isUntaggedTag(tag: string | null | undefined): boolean {
  const normalized = tag?.trim().toLowerCase() ?? "";
  return normalized === "untagged" || normalized === "sans tag";
}

function resolveTagColor(
  tag: string,
  color: string | null | undefined,
  index: number,
): string {
  if (isUntaggedTag(tag)) {
    return UNTAGGED_TAG_COLOR;
  }
  if (typeof color === "string" && color.trim().length > 0) {
    return color;
  }
  return TAG_FALLBACK_COLORS[index % TAG_FALLBACK_COLORS.length];
}

/* ── Dashboard Charts (Client Component) ────────────── */

interface DashboardChartsProps {
  month: string;
  spending: DashboardSpending | null;
  trends: DashboardTrends | null;
  topExpenses: DashboardTopExpenses | null;
  displayMode: CurrencyDisplayMode;
  assumedCurrency: string;
}

type DashboardTooltipProps = TooltipContentProps<
  number | string | ReadonlyArray<number | string>,
  string | number
>;

export function DashboardCharts({
  month,
  spending,
  trends,
  topExpenses,
  displayMode,
  assumedCurrency,
}: DashboardChartsProps) {
  const router = useRouter();
  const isCurrentMonth = month === currentMonthStr();

  function handleMonthChange(offset: number) {
    const newMonth = shiftMonth(month, offset);
    const params = new URLSearchParams();
    params.set("month", newMonth);
    router.push(`/?${params.toString()}`);
  }

  return (
    <div className="space-y-8">
      {/* Month Selector */}
      <div className="flex items-center justify-center gap-4">
        <Button
          variant="ghost"
          size="icon"
          onClick={() => handleMonthChange(-1)}
          aria-label="Mois précédent"
        >
          <ChevronLeft className="h-5 w-5" />
        </Button>
        <span className="min-w-[200px] text-center text-lg font-semibold capitalize">
          {formatMonthLabel(month)}
        </span>
        <Button
          variant="ghost"
          size="icon"
          onClick={() => handleMonthChange(1)}
          disabled={isCurrentMonth}
          aria-label="Mois suivant"
        >
          <ChevronRight className="h-5 w-5" />
        </Button>
      </div>

      {/* Charts Row */}
      <div className="grid gap-6 lg:grid-cols-2">
        <SpendingBreakdown
          spending={spending}
          month={month}
          displayMode={displayMode}
          assumedCurrency={assumedCurrency}
        />
        <TrendsChart
          trends={trends}
          displayMode={displayMode}
          assumedCurrency={assumedCurrency}
        />
      </div>

      {/* Top Expenses */}
      <TopExpensesList
        topExpenses={topExpenses}
        displayMode={displayMode}
        assumedCurrency={assumedCurrency}
      />
    </div>
  );
}

/* ── Spending Breakdown (Pie Chart) ──────────────────── */

function SpendingBreakdown({
  spending,
  month,
  displayMode,
  assumedCurrency,
}: {
  spending: DashboardSpending | null;
  month: string;
  displayMode: CurrencyDisplayMode;
  assumedCurrency: string;
}) {
  const router = useRouter();
  const { baseCurrency, rates } = useCurrency();

  if (!spending) {
    return (
      <div className="border border-border bg-card p-6">
        <div className="flex h-64 items-center justify-center text-sm text-muted-foreground">
          Chargement…
        </div>
      </div>
    );
  }

  const convertForChart = (value: number): number => {
    if (displayMode !== "base") return value;
    const converted = convertAmountValue(
      String(value),
      assumedCurrency,
      baseCurrency,
      rates,
    );
    return converted ?? value;
  };

  const formatForDisplay = (value: number): string => {
    const numeric = displayMode === "base" ? convertForChart(value) : value;
    const currency = displayMode === "base" ? baseCurrency : assumedCurrency;
    return formatAmount(String(numeric), currency);
  };

  const data = spending.by_tag.map((t, index) => {
    const rawValue = Math.abs(parseFloat(t.amount));
    return {
      name: t.tag,
      value: convertForChart(rawValue),
      color: resolveTagColor(t.tag, t.color, index),
      percentage: t.percentage,
    };
  });

  const hasData = data.length > 0;

  return (
    <div className="border border-border bg-card p-6">
      <h3 className="mb-1 text-sm font-semibold text-muted-foreground">
        Dépenses par tag
      </h3>
      <p className="mb-4 text-xs text-muted-foreground">
        Total :{" "}
        <span className="font-medium text-danger">
          {formatForDisplay(Math.abs(parseFloat(spending.total_expenses)))}
        </span>
      </p>
      <p className="mb-4 text-xs text-muted-foreground">
        Hypothèse mono-devise pour ces agrégats.
      </p>

      {!hasData ? (
        <div className="flex h-48 items-center justify-center text-sm text-muted-foreground">
          Aucune dépense ce mois
        </div>
      ) : (
        <div className="flex flex-col items-center gap-4 lg:flex-row">
          <ChartContainer
            config={spendingChartConfig}
            className="h-56 min-h-[224px] w-56 shrink-0 [&_.recharts-sector]:transition-opacity [&_.recharts-sector]:duration-200"
          >
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
                stroke="var(--color-background)"
                strokeWidth={2}
                cursor="pointer"
                onClick={(entry) => {
                  const tag = entry?.name;
                  if (tag && !isUntaggedTag(String(tag))) {
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
              <ChartTooltip
                content={(props: DashboardTooltipProps) => {
                  const payload = (props.payload ?? []).map((entry) => {
                    const amount = toNumber(entry.value);
                    const percentage =
                      (entry.payload as { percentage?: number } | undefined)
                        ?.percentage ?? 0;
                    return {
                      ...entry,
                      name: "Montant",
                      value: `${formatForDisplay(amount)} (${percentage}%)`,
                    };
                  });
                  const label = (
                    props.payload?.[0]?.payload as { name?: string } | undefined
                  )?.name;
                  return (
                    <ChartTooltipContent
                      active={props.active}
                      payload={payload}
                      label={label}
                      hideIndicator
                    />
                  );
                }}
                wrapperStyle={{ outline: "none" }}
              />
            </PieChart>
          </ChartContainer>

          <div className="flex-1 space-y-2">
            {data.map((entry, i) => (
              <div key={i} className="flex items-center gap-2 text-sm">
                <span
                  className={`inline-block h-3 w-3 shrink-0 ${
                    isUntaggedTag(entry.name) ? "ring-1 ring-foreground/40" : ""
                  }`}
                  style={{ backgroundColor: entry.color }}
                />
                <span className="flex-1 truncate">{entry.name}</span>
                <span className="font-medium tabular-nums">
                  {formatForDisplay(entry.value)}
                </span>
                <span className="w-12 text-right text-xs text-muted-foreground tabular-nums">
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

/* ── Trends Chart (Bar Chart) ────────────────────────── */

function TrendsChart({
  trends,
  displayMode,
  assumedCurrency,
}: {
  trends: DashboardTrends | null;
  displayMode: CurrencyDisplayMode;
  assumedCurrency: string;
}) {
  const { baseCurrency, rates } = useCurrency();
  if (!trends) {
    return (
      <div className="border border-border bg-card p-6">
        <div className="flex h-64 items-center justify-center text-sm text-muted-foreground">
          Chargement…
        </div>
      </div>
    );
  }

  const convertForChart = (value: number): number => {
    if (displayMode !== "base") return value;
    const converted = convertAmountValue(
      String(value),
      assumedCurrency,
      baseCurrency,
      rates,
    );
    return converted ?? value;
  };

  const formatForDisplay = (value: number): string => {
    const numeric = displayMode === "base" ? convertForChart(value) : value;
    const currency = displayMode === "base" ? baseCurrency : assumedCurrency;
    return formatAmount(String(numeric), currency);
  };

  const data = [...trends.months]
    .reverse()
    .map((m) => ({
      month: formatShortMonth(m.month),
      income: convertForChart(parseFloat(m.income)),
      expense: convertForChart(Math.abs(parseFloat(m.expenses))),
    }));

  const hasData = data.some((d) => d.income > 0 || d.expense > 0);

  return (
    <div className="border border-border bg-card p-6">
      <h3 className="mb-4 text-sm font-semibold text-muted-foreground">
        Revenus vs Dépenses
      </h3>
      <p className="mb-4 text-xs text-muted-foreground">
        Hypothèse mono-devise pour ces agrégats.
      </p>

      {!hasData ? (
        <div className="flex h-48 items-center justify-center text-sm text-muted-foreground">
          Aucune donnée disponible
        </div>
      ) : (
        <ChartContainer
          config={trendsChartConfig}
          className="h-64 min-h-[256px] w-full"
        >
          <BarChart data={data} barGap={6}>
            <CartesianGrid
              strokeDasharray="3 3"
              vertical={false}
              stroke="var(--color-border)"
              strokeOpacity={0.45}
            />
            <XAxis
              dataKey="month"
              axisLine={false}
              tickLine={false}
              tick={{ fill: "var(--color-muted-foreground)", fontSize: 12 }}
            />
            <YAxis
              axisLine={false}
              tickLine={false}
              tick={{ fill: "var(--color-muted-foreground)", fontSize: 12 }}
              tickFormatter={(v) =>
                v >= 1000 ? `${(v / 1000).toFixed(0)}k` : String(v)
              }
            />
            <ChartTooltip
              content={(props: DashboardTooltipProps) => {
                const payload = (props.payload ?? []).map((entry) => ({
                  ...entry,
                  value: formatForDisplay(toNumber(entry.value)),
                }));
                return (
                  <ChartTooltipContent
                    active={props.active}
                    payload={payload}
                    label={props.label}
                  />
                );
              }}
              wrapperStyle={{ outline: "none" }}
              cursor={{ fill: "rgba(255,255,255,0.03)" }}
            />
            <ChartLegend content={<ChartLegendContent />} />
            <Bar
              dataKey="income"
              fill="var(--color-income)"
              radius={[4, 4, 0, 0]}
              maxBarSize={32}
            />
            <Bar
              dataKey="expense"
              fill="var(--color-expense)"
              radius={[4, 4, 0, 0]}
              maxBarSize={32}
            />
          </BarChart>
        </ChartContainer>
      )}
    </div>
  );
}

/* ── Top 5 Expenses ──────────────────────────────────── */

function TopExpensesList({
  topExpenses,
  displayMode,
  assumedCurrency,
}: {
  topExpenses: DashboardTopExpenses | null;
  displayMode: CurrencyDisplayMode;
  assumedCurrency: string;
}) {
  const { baseCurrency, rates } = useCurrency();
  if (!topExpenses) return null;

  const { expenses } = topExpenses;
  const formatForDisplay = (value: string): string => {
    const parsed = Math.abs(parseFloat(value));
    if (displayMode !== "base") return formatAmount(String(parsed), assumedCurrency);
    const converted = convertAmountValue(
      String(parsed),
      assumedCurrency,
      baseCurrency,
      rates,
    );
    return formatAmount(String(converted ?? parsed), baseCurrency);
  };

  return (
    <section>
      <h2 className="mb-4 text-lg font-semibold">Top 5 dépenses</h2>
      <p className="mb-4 text-xs text-muted-foreground">
        Hypothèse mono-devise pour ces agrégats.
      </p>
      {expenses.length === 0 ? (
        <div className="border border-dashed border-border bg-card p-6 text-center text-sm text-muted-foreground">
          Aucune dépense ce mois
        </div>
      ) : (
        <div className="overflow-hidden rounded-md border border-border bg-card">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Date</TableHead>
                <TableHead>Libellé</TableHead>
                <TableHead>Tags</TableHead>
                <TableHead>Compte</TableHead>
                <TableHead className="text-right">Montant</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {expenses.map((expense) => (
                <TableRow key={expense.id}>
                  <TableCell className="whitespace-nowrap text-muted-foreground tabular-nums">
                    {formatDate(expense.date)}
                  </TableCell>
                  <TableCell className="max-w-xs truncate">
                    {expense.label}
                  </TableCell>
                  <TableCell>
                    <span className="inline-flex flex-wrap gap-1">
                      {expense.tags.length > 0 ? (
                        expense.tags.map((tag) => (
                          <span
                            key={tag}
                            className="inline-flex items-center bg-accent px-2 py-0.5 text-xs text-muted-foreground"
                          >
                            {tag}
                          </span>
                        ))
                      ) : (
                        <span className="text-muted-foreground/50">—</span>
                      )}
                    </span>
                  </TableCell>
                  <TableCell className="whitespace-nowrap text-muted-foreground">
                    {expense.account}
                  </TableCell>
                  <TableCell className="text-right font-semibold text-danger tabular-nums">
                    {formatForDisplay(expense.amount)}
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </div>
      )}
    </section>
  );
}
