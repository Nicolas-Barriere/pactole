import Link from "next/link";
import { notFound } from "next/navigation";
import { serverApi } from "@/lib/server-api";
import { AccountActions, BalanceEditor } from "@/components/account-detail-client";
import { ConvertedAmount } from "@/components/converted-amount";
import { TransactionAmount } from "@/components/transaction-amount";
import { Badge } from "@/components/ui/badge";
import { ArrowLeft, Upload } from "lucide-react";
import {
  BANK_LABELS,
  getAccountTypeBadgeClass,
  getAccountTypeBadgeVariant,
  getAccountTypeLabel,
} from "@/lib/account-metadata";
import { cn } from "@/lib/utils";
import type { Account, Transaction, Import, PaginatedResponse } from "@/types";

function formatDate(iso: string): string {
  return new Intl.DateTimeFormat("fr-FR", {
    day: "numeric",
    month: "short",
    year: "numeric",
  }).format(new Date(iso));
}

const IMPORT_STATUS_LABELS: Record<string, string> = {
  completed: "Terminé",
  processing: "En cours",
  pending: "En attente",
  failed: "Échoué",
};

const IMPORT_STATUS_VARIANT: Record<
  string,
  "success" | "warning" | "default" | "destructive"
> = {
  completed: "success",
  processing: "warning",
  pending: "default",
  failed: "destructive",
};

/* ── Page (Server Component) ─────────────────────────── */

export default async function AccountDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;

  let account: Account;
  let transactions: Transaction[] = [];
  let imports: Import[] = [];

  try {
    account = await serverApi.get<Account>(`/accounts/${id}`);
  } catch {
    notFound();
  }

  try {
    const res = await serverApi.get<PaginatedResponse<Transaction>>(
      `/accounts/${id}/transactions?per_page=20`,
    );
    transactions = res.data ?? [];
  } catch {
    /* non-critical */
  }

  try {
    const data = await serverApi.get<Import[]>(`/accounts/${id}/imports`);
    imports = Array.isArray(data) ? data : [];
  } catch {
    /* non-critical */
  }

  const balance = parseFloat(account.balance);

  return (
    <div className="space-y-6">
      {/* Back link */}
      <Link
        href="/accounts"
        className="inline-flex items-center gap-1.5 text-sm text-muted-foreground transition-colors hover:text-foreground"
      >
        <ArrowLeft className="h-4 w-4" />
        Comptes
      </Link>

      {/* ── Header ─────────────────────────────────── */}
      <div className="border border-border bg-card p-6">
        <div className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
          <div>
            <div className="mb-2 flex flex-wrap items-center gap-2">
              <Badge
                variant={getAccountTypeBadgeVariant(account.type)}
                className={cn("text-sm", getAccountTypeBadgeClass(account.type))}
              >
                {getAccountTypeLabel(account.type)}
              </Badge>
              <span className="text-xs text-muted-foreground">
                {BANK_LABELS[account.bank] ?? account.bank}
              </span>
              <span className="text-xs text-muted-foreground">&middot;</span>
              <span className="text-xs text-muted-foreground">
                {account.currency}
              </span>
            </div>
            <h1 className="text-2xl font-bold tracking-tight">{account.name}</h1>
            <p
              className={`mt-1 text-3xl font-bold tabular-nums ${
                balance >= 0 ? "text-foreground" : "text-danger"
              }`}
            >
              <ConvertedAmount
                amount={account.balance}
                fromCurrency={account.currency}
              />
            </p>
          </div>

          {/* Client component for edit/archive actions */}
          <AccountActions account={account} />
        </div>

        <div className="mt-4 flex flex-wrap items-center gap-6 border-t border-border pt-4 text-sm text-muted-foreground">
          <span>{account.transaction_count} transactions</span>
          <span className="inline-flex items-center gap-1.5">
            Solde initial :{" "}
            {/* Client component for inline balance editing */}
            <BalanceEditor account={account} />
          </span>
          {account.last_import_at && (
            <span>Dernier import : {formatDate(account.last_import_at)}</span>
          )}
        </div>
      </div>

      {/* ── Recent Transactions ────────────────────── */}
      <section>
        <div className="mb-3 flex items-center justify-between">
          <h2 className="text-lg font-semibold">Transactions récentes</h2>
          {transactions.length > 0 && (
            <Link
              href={`/transactions?account=${account.id}`}
              className="text-sm font-medium text-primary hover:text-primary/80"
            >
              Voir tout
            </Link>
          )}
        </div>

        {transactions.length === 0 ? (
          <div className="border border-dashed border-border bg-card p-8 text-center text-sm text-muted-foreground">
            Aucune transaction pour ce compte.
          </div>
        ) : (
          <div className="overflow-hidden border border-border bg-card">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-border text-left text-xs text-muted-foreground">
                  <th className="px-4 py-3 font-medium">Date</th>
                  <th className="px-4 py-3 font-medium">Libellé</th>
                  <th className="px-4 py-3 font-medium">Tags</th>
                  <th className="px-4 py-3 text-right font-medium">Montant</th>
                </tr>
              </thead>
              <tbody>
                {transactions.map((tx) => {
                  return (
                    <tr
                      key={tx.id}
                      className="border-b border-border last:border-0 hover:bg-accent"
                    >
                      <td className="whitespace-nowrap px-4 py-3 text-muted-foreground">
                        {formatDate(tx.date)}
                      </td>
                      <td className="px-4 py-3">{tx.label}</td>
                      <td className="px-4 py-3 text-muted-foreground">
                        {tx.tags.length > 0 ? (
                          <span className="flex flex-wrap gap-1">
                            {tx.tags.map((tag) => (
                              <span
                                key={tag.id}
                                className="inline-flex items-center gap-1 px-2 py-0.5 text-xs font-medium"
                                style={{
                                  backgroundColor: tag.color + "20",
                                  color: tag.color,
                                }}
                              >
                                <span
                                  className="inline-block h-1.5 w-1.5 rounded-full"
                                  style={{ backgroundColor: tag.color }}
                                />
                                {tag.name}
                              </span>
                            ))}
                          </span>
                        ) : (
                          <span className="text-muted-foreground/50">—</span>
                        )}
                      </td>
                      <td className="px-4 py-3 text-right">
                        <TransactionAmount
                          amount={tx.amount}
                          currency={tx.currency}
                        />
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </section>

      {/* ── Import Section ─────────────────────────── */}
      <section>
        <div className="mb-3 flex items-center justify-between">
          <h2 className="text-lg font-semibold">Imports</h2>
          <Link
            href={`/import?account=${account.id}`}
            className="flex items-center gap-2 bg-primary px-4 py-2 text-sm font-medium text-primary-foreground transition-colors hover:bg-primary/90"
          >
            <Upload className="h-4 w-4" />
            Importer un CSV
          </Link>
        </div>

        {imports.length === 0 ? (
          <div className="border border-dashed border-border bg-card p-8 text-center text-sm text-muted-foreground">
            Aucun import pour ce compte.
          </div>
        ) : (
          <div className="overflow-hidden border border-border bg-card">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-border text-left text-xs text-muted-foreground">
                  <th className="px-4 py-3 font-medium">Date</th>
                  <th className="px-4 py-3 font-medium">Fichier</th>
                  <th className="px-4 py-3 font-medium">Lignes</th>
                  <th className="px-4 py-3 font-medium">Statut</th>
                </tr>
              </thead>
              <tbody>
                {imports.map((imp) => (
                  <tr
                    key={imp.id}
                    className="border-b border-border last:border-0 hover:bg-accent"
                  >
                    <td className="whitespace-nowrap px-4 py-3 text-muted-foreground">
                      {formatDate(imp.inserted_at)}
                    </td>
                    <td className="px-4 py-3 font-mono text-xs">
                      {imp.filename}
                    </td>
                    <td className="px-4 py-3 text-muted-foreground">
                      <span className="text-foreground">{imp.rows_imported}</span>
                      {" importées"}
                      {imp.rows_skipped > 0 && (
                        <span className="text-warning">
                          {" / "}
                          {imp.rows_skipped} ignorées
                        </span>
                      )}
                      {imp.rows_errored > 0 && (
                        <span className="text-danger">
                          {" / "}
                          {imp.rows_errored} erreurs
                        </span>
                      )}
                    </td>
                    <td className="px-4 py-3">
                      <Badge
                        variant={
                          IMPORT_STATUS_VARIANT[imp.status] ?? "secondary"
                        }
                      >
                        {IMPORT_STATUS_LABELS[imp.status] ?? imp.status}
                      </Badge>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </div>
  );
}
