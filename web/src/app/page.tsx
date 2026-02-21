import Link from "next/link";
import { serverApi } from "@/lib/server-api";
import { DashboardCharts } from "@/components/dashboard-charts";
import { ConvertedAmount } from "@/components/converted-amount";
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

function currentMonthStr(): string {
  const now = new Date();
  const m = String(now.getMonth() + 1).padStart(2, "0");
  return `${now.getFullYear()}-${m}`;
}

const ACCOUNT_TYPE_ICONS: Record<AccountType, { icon: string; color: string }> =
  {
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

/* ── Dashboard Page (Server Component) ──────────────── */

export default async function DashboardPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string>>;
}) {
  const params = await searchParams;
  const month = params.month ?? currentMonthStr();

  let summary: DashboardSummary | null = null;
  let spending: DashboardSpending | null = null;
  let trends: DashboardTrends | null = null;
  let topExpenses: DashboardTopExpenses | null = null;

  try {
    [summary, spending, trends, topExpenses] = await Promise.all([
      serverApi.get<DashboardSummary>("/dashboard/summary"),
      serverApi.get<DashboardSpending>(`/dashboard/spending?month=${month}`),
      serverApi.get<DashboardTrends>("/dashboard/trends?months=12"),
      serverApi.get<DashboardTopExpenses>(
        `/dashboard/top-expenses?month=${month}&limit=5`,
      ),
    ]);
  } catch {
    /* silently fail — show empty state */
  }

  const isEmpty = summary && summary.accounts.length === 0;

  if (isEmpty || !summary) {
    return <EmptyState />;
  }

  /* Compute last-month net change from trends */
  const changeVsLastMonth = (() => {
    if (!trends || trends.months.length < 2) return null;
    const lastMonth = trends.months[1];
    if (!lastMonth) return null;
    const net = parseFloat(lastMonth.net);
    return net === 0 ? null : net;
  })();

  return (
    <div className="space-y-8">
      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold tracking-tight">Tableau de bord</h1>
        <p className="text-sm text-muted-foreground">
          Vue d&apos;ensemble de vos finances
        </p>
      </div>

      {/* Net Worth */}
      <div className="border border-border bg-card p-6">
        <p className="text-sm font-medium text-muted-foreground">Patrimoine net</p>
        <div className="mt-1 flex items-baseline gap-3">
          <p className="text-3xl font-bold tracking-tight">
            <ConvertedAmount
              amount={summary.net_worth}
              fromCurrency={summary.currency}
            />
          </p>
          {changeVsLastMonth !== null && (
            <span
              className={`text-sm font-medium ${
                changeVsLastMonth >= 0 ? "text-success" : "text-danger"
              }`}
            >
              {changeVsLastMonth >= 0 ? "+" : ""}
              <ConvertedAmount
                amount={String(changeVsLastMonth)}
                fromCurrency={summary.currency}
              />{" "}
              <span className="text-muted-foreground">le mois dernier</span>
            </span>
          )}
        </div>
        <p className="mt-1 text-xs text-muted-foreground">{summary.currency}</p>
      </div>

      {/* Account Cards */}
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
                    <p className="truncate text-sm font-semibold">
                      {account.name}
                    </p>
                    <p className="truncate text-xs text-muted-foreground">
                      {BANK_LABELS[account.bank] ?? account.bank}
                    </p>
                  </div>
                </div>
                <p className="mt-3 text-lg font-bold tracking-tight">
                  <ConvertedAmount
                    amount={account.balance}
                    fromCurrency={summary.currency}
                  />
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

      {/* Charts + Month Selector (client component) */}
      <DashboardCharts
        month={month}
        spending={spending}
        trends={trends}
        topExpenses={topExpenses}
      />
    </div>
  );
}

/* ── Empty State ─────────────────────────────────────── */

function EmptyState() {
  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-2xl font-bold tracking-tight">Tableau de bord</h1>
        <p className="text-sm text-muted-foreground">
          Vue d&apos;ensemble de vos finances
        </p>
      </div>

      <div className="flex flex-col items-center justify-center border border-dashed border-border bg-card px-6 py-16 text-center">
        <div className="mb-4 text-5xl">📊</div>
        <h2 className="mb-2 text-xl font-semibold">Bienvenue sur Moulax</h2>
        <p className="mb-6 max-w-md text-sm text-muted-foreground">
          Commencez par créer un compte bancaire puis importez votre premier
          relevé CSV pour voir votre tableau de bord prendre vie.
        </p>
        <div className="flex gap-3">
          <Link
            href="/accounts"
            className="bg-primary px-4 py-2 text-sm font-medium text-primary-foreground transition-colors hover:bg-primary/90"
          >
            Créer un compte
          </Link>
          <Link
            href="/import"
            className="border border-border bg-card px-4 py-2 text-sm font-medium transition-colors hover:bg-accent"
          >
            Importer un relevé
          </Link>
        </div>
      </div>
    </div>
  );
}
