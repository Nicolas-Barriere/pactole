import Link from "next/link";
import { serverApi } from "@/lib/server-api";
import { AccountsClient } from "@/components/accounts-client";
import { ConvertedAmount } from "@/components/converted-amount";
import { Badge } from "@/components/ui/badge";
import {
  BANK_LABELS,
  getAccountTypeBadgeClass,
  getAccountTypeBadgeVariant,
  getAccountTypeLabel,
} from "@/lib/account-metadata";
import { cn } from "@/lib/utils";
import type { Account } from "@/types";

function formatDate(iso: string): string {
  return new Intl.DateTimeFormat("fr-FR", {
    day: "numeric",
    month: "short",
    year: "numeric",
  }).format(new Date(iso));
}

/* ── Page (Server Component) ─────────────────────────── */

export default async function AccountsPage() {
  let accounts: Account[] = [];
  let error: string | null = null;

  try {
    accounts = await serverApi.get<Account[]>("/accounts");
  } catch {
    error = "Impossible de charger les comptes";
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold tracking-tight">Comptes</h1>
          <p className="text-sm text-muted-foreground">
            Gérez vos comptes bancaires
          </p>
        </div>
        <AccountsClient />
      </div>

      {error && (
        <div className="border border-destructive/30 bg-destructive/5 p-6 text-center">
          <p className="text-sm text-destructive">{error}</p>
        </div>
      )}

      {!error && accounts.length === 0 && (
        <div className="border border-dashed border-border bg-card p-12 text-center">
          <p className="text-sm text-muted-foreground">
            Aucun compte pour le moment.
          </p>
        </div>
      )}

      {!error && accounts.length > 0 && (
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {accounts.map((account) => (
            <AccountCard key={account.id} account={account} />
          ))}
        </div>
      )}
    </div>
  );
}

/* ── Account Card ────────────────────────────────────── */

function AccountCard({ account }: { account: Account }) {
  const balance = parseFloat(account.balance);

  return (
    <Link
      href={`/accounts/${account.id}`}
      className="group border border-border bg-card p-5 transition-colors hover:border-primary/30 hover:bg-accent"
    >
      <div className="mb-3 flex items-center justify-between">
        <Badge
          variant={getAccountTypeBadgeVariant(account.type)}
          className={cn("text-sm", getAccountTypeBadgeClass(account.type))}
        >
          {getAccountTypeLabel(account.type)}
        </Badge>
        <span className="text-xs text-muted-foreground">
          {BANK_LABELS[account.bank] ?? account.bank}
        </span>
      </div>

      <h3 className="mb-1 font-semibold tracking-tight group-hover:text-primary">
        {account.name}
      </h3>

      <p
        className={`text-2xl font-bold tabular-nums ${
          balance >= 0 ? "text-foreground" : "text-danger"
        }`}
      >
        <ConvertedAmount amount={account.balance} fromCurrency={account.currency} />
      </p>

      <div className="mt-3 flex items-center justify-between text-xs text-muted-foreground">
        <span>{account.transaction_count} transactions</span>
        {account.last_import_at ? (
          <span>Import {formatDate(account.last_import_at)}</span>
        ) : (
          <span>Aucun import</span>
        )}
      </div>
    </Link>
  );
}
