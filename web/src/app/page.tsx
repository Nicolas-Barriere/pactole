import Link from "next/link";
import { serverApi } from "@/lib/server-api";
import { DashboardPageClient } from "@/components/dashboard-page-client";
import type {
  DashboardSummary,
  DashboardSpending,
  DashboardTrends,
  DashboardTopExpenses,
} from "@/types";

function currentMonthStr(): string {
  const now = new Date();
  const m = String(now.getMonth() + 1).padStart(2, "0");
  return `${now.getFullYear()}-${m}`;
}

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

  return (
    <DashboardPageClient
      month={month}
      summary={summary}
      spending={spending}
      trends={trends}
      topExpenses={topExpenses}
    />
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
