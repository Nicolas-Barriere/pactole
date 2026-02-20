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
  Tooltip,
  ResponsiveContainer,
  Legend,
} from "recharts";
import { ChevronLeft, ChevronRight } from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import type {
  DashboardSpending,
  DashboardTrends,
  DashboardTopExpenses,
} from "@/types";

/* ── Helpers ─────────────────────────────────────────── */

function formatAmount(amount: string | number, currency = "EUR"): string {
  return new Intl.NumberFormat("fr-FR", {
    style: "currency",
    currency,
  }).format(typeof amount === "string" ? parseFloat(amount) : amount);
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

/* ── Dashboard Charts (Client Component) ────────────── */

interface DashboardChartsProps {
  month: string;
  spending: DashboardSpending | null;
  trends: DashboardTrends | null;
  topExpenses: DashboardTopExpenses | null;
}

export function DashboardCharts({
  month,
  spending,
  trends,
  topExpenses,
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
        <SpendingBreakdown spending={spending} month={month} />
        <TrendsChart trends={trends} />
      </div>

      {/* Top Expenses */}
      <TopExpensesList topExpenses={topExpenses} />
    </div>
  );
}

/* ── Spending Breakdown (Pie Chart) ──────────────────── */

function SpendingBreakdown({
  spending,
  month,
}: {
  spending: DashboardSpending | null;
  month: string;
}) {
  const router = useRouter();

  if (!spending) {
    return (
      <div className="border border-border bg-card p-6">
        <div className="flex h-64 items-center justify-center text-sm text-muted-foreground">
          Chargement…
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
    <div className="border border-border bg-card p-6">
      <h3 className="mb-1 text-sm font-semibold text-muted-foreground">
        Dépenses par tag
      </h3>
      <p className="mb-4 text-xs text-muted-foreground">
        Total :{" "}
        <span className="font-medium text-danger">
          {formatAmount(spending.total_expenses)}
        </span>
      </p>

      {!hasData ? (
        <div className="flex h-48 items-center justify-center text-sm text-muted-foreground">
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
                  className="inline-block h-3 w-3 shrink-0"
                  style={{ backgroundColor: entry.color }}
                />
                <span className="flex-1 truncate">{entry.name}</span>
                <span className="font-medium tabular-nums">
                  {formatAmount(String(-entry.value))}
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

function SpendingTooltip({
  active,
  payload,
}: Partial<TooltipContentProps<number, string>>) {
  if (!active || !payload?.[0]) return null;
  const data = payload[0].payload as {
    name: string;
    value: number;
    percentage: number;
  };
  return (
    <div className="border border-border bg-card px-3 py-2 text-sm shadow-lg">
      <p className="font-medium">{data.name}</p>
      <p className="text-muted-foreground">
        {formatAmount(String(-data.value))} ({data.percentage}%)
      </p>
    </div>
  );
}

/* ── Trends Chart (Bar Chart) ────────────────────────── */

function TrendsChart({ trends }: { trends: DashboardTrends | null }) {
  if (!trends) {
    return (
      <div className="border border-border bg-card p-6">
        <div className="flex h-64 items-center justify-center text-sm text-muted-foreground">
          Chargement…
        </div>
      </div>
    );
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
    <div className="border border-border bg-card p-6">
      <h3 className="mb-4 text-sm font-semibold text-muted-foreground">
        Revenus vs Dépenses
      </h3>

      {!hasData ? (
        <div className="flex h-48 items-center justify-center text-sm text-muted-foreground">
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
              <Tooltip
                content={<TrendTooltip />}
                wrapperStyle={{ outline: "none" }}
                cursor={{ fill: "rgba(255,255,255,0.03)" }}
              />
              <Legend
                iconType="square"
                iconSize={10}
                wrapperStyle={{
                  fontSize: 12,
                  color: "var(--color-muted-foreground)",
                }}
              />
              <Bar
                dataKey="Revenus"
                fill="var(--color-success)"
                radius={[2, 2, 0, 0]}
                maxBarSize={32}
              />
              <Bar
                dataKey="Dépenses"
                fill="var(--color-danger)"
                radius={[2, 2, 0, 0]}
                maxBarSize={32}
              />
            </BarChart>
          </ResponsiveContainer>
        </div>
      )}
    </div>
  );
}

function TrendTooltip({
  active,
  payload,
  label,
}: Partial<TooltipContentProps<number, string>>) {
  if (!active || !payload?.length) return null;
  return (
    <div className="border border-border bg-card px-3 py-2 text-sm shadow-lg">
      <p className="mb-1 font-medium capitalize">{label}</p>
      {payload.map(
        (entry: { dataKey?: string; color?: string; value?: number }) => (
          <p key={entry.dataKey} style={{ color: entry.color }}>
            {entry.dataKey} : {formatAmount(String(entry.value ?? 0))}
          </p>
        ),
      )}
    </div>
  );
}

/* ── Top 5 Expenses ──────────────────────────────────── */

function TopExpensesList({
  topExpenses,
}: {
  topExpenses: DashboardTopExpenses | null;
}) {
  if (!topExpenses) return null;

  const { expenses } = topExpenses;

  return (
    <section>
      <h2 className="mb-4 text-lg font-semibold">Top 5 dépenses</h2>
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
                    {formatAmount(expense.amount)}
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
