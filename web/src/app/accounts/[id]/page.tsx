"use client";

import { useEffect, useState, useCallback } from "react";
import { useParams, useRouter } from "next/navigation";
import Link from "next/link";
import { api, ApiError } from "@/lib/api";
import { useToast } from "@/components/toast";
import { ConfirmDialog } from "@/components/confirm-dialog";
import {
  AccountForm,
  BANK_LABELS,
  TYPE_LABELS,
  TYPE_BADGE_STYLES,
  type AccountFormData,
} from "@/components/account-form";
import type { Account, Transaction, Import, PaginatedResponse } from "@/types";

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

const IMPORT_STATUS_STYLES: Record<string, string> = {
  completed: "bg-success/15 text-success",
  processing: "bg-warning/15 text-warning",
  pending: "bg-primary/15 text-primary",
  failed: "bg-danger/15 text-danger",
};

const IMPORT_STATUS_LABELS: Record<string, string> = {
  completed: "Terminé",
  processing: "En cours",
  pending: "En attente",
  failed: "Échoué",
};

export default function AccountDetailPage() {
  const params = useParams<{ id: string }>();
  const router = useRouter();
  const toast = useToast();

  const [account, setAccount] = useState<Account | null>(null);
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [imports, setImports] = useState<Import[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const [editOpen, setEditOpen] = useState(false);
  const [editLoading, setEditLoading] = useState(false);
  const [archiveOpen, setArchiveOpen] = useState(false);
  const [archiveLoading, setArchiveLoading] = useState(false);
  const [editingBalance, setEditingBalance] = useState(false);
  const [balanceInput, setBalanceInput] = useState("");

  const fetchAccount = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const data = await api.get<Account>(`/accounts/${params.id}`);
      setAccount(data);
    } catch (err) {
      if (err instanceof ApiError && err.status === 404) {
        setError("Compte introuvable");
      } else {
        setError("Impossible de charger le compte");
      }
    } finally {
      setLoading(false);
    }
  }, [params.id]);

  const fetchTransactions = useCallback(async () => {
    try {
      const res = await api.get<PaginatedResponse<Transaction>>(
        `/accounts/${params.id}/transactions?per_page=20`,
      );
      setTransactions(res.data ?? []);
    } catch {
      /* transactions are non-critical, silently fail */
    }
  }, [params.id]);

  const fetchImports = useCallback(async () => {
    try {
      const data = await api.get<Import[]>(
        `/accounts/${params.id}/imports`,
      );
      setImports(Array.isArray(data) ? data : []);
    } catch {
      /* imports are non-critical, silently fail */
    }
  }, [params.id]);

  useEffect(() => {
    fetchAccount();
    fetchTransactions();
    fetchImports();
  }, [fetchAccount, fetchTransactions, fetchImports]);

  async function handleEdit(data: AccountFormData) {
    try {
      setEditLoading(true);
      const updated = await api.put<Account>(`/accounts/${params.id}`, data);
      setAccount(updated);
      toast.success("Compte modifié avec succès");
      setEditOpen(false);
    } catch (err) {
      if (err instanceof ApiError && err.body) {
        const body = err.body as { errors?: Record<string, string[]> };
        const messages = body.errors
          ? Object.values(body.errors).flat().join(", ")
          : "Erreur lors de la modification";
        toast.error(messages);
      } else {
        toast.error("Erreur de connexion");
      }
    } finally {
      setEditLoading(false);
    }
  }

  async function handleArchive() {
    try {
      setArchiveLoading(true);
      await api.delete(`/accounts/${params.id}`);
      toast.success("Compte archivé avec succès");
      router.push("/accounts");
    } catch {
      toast.error("Erreur lors de l'archivage");
      setArchiveLoading(false);
    }
  }

  function startEditingBalance() {
    if (account) {
      setBalanceInput(account.initial_balance);
      setEditingBalance(true);
    }
  }

  async function saveInitialBalance() {
    const value = balanceInput.trim();
    if (!value || isNaN(parseFloat(value))) {
      setEditingBalance(false);
      return;
    }
    if (account && value === account.initial_balance) {
      setEditingBalance(false);
      return;
    }
    try {
      const updated = await api.put<Account>(`/accounts/${params.id}`, {
        initial_balance: value,
      });
      setAccount(updated);
      fetchTransactions();
      toast.success("Solde initial modifié");
    } catch {
      toast.error("Erreur lors de la modification du solde initial");
    } finally {
      setEditingBalance(false);
    }
  }

  function handleBalanceKeyDown(e: React.KeyboardEvent) {
    if (e.key === "Enter") {
      e.preventDefault();
      saveInitialBalance();
    } else if (e.key === "Escape") {
      setEditingBalance(false);
    }
  }

  if (loading) {
    return <AccountDetailSkeleton />;
  }

  if (error || !account) {
    return (
      <div className="space-y-6">
        <BackLink />
        <div className="rounded-xl border border-danger/30 bg-danger/5 p-8 text-center">
          <p className="text-sm text-danger">{error ?? "Erreur inconnue"}</p>
          <Link
            href="/accounts"
            className="mt-3 inline-block text-sm font-medium text-primary hover:text-primary-hover"
          >
            Retour aux comptes
          </Link>
        </div>
      </div>
    );
  }

  const balance = parseFloat(account.balance);

  return (
    <div className="space-y-6">
      <BackLink />

      {/* ── Header ─────────────────────────────────── */}
      <div className="rounded-xl border border-border bg-card p-6">
        <div className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
          <div>
            <div className="mb-2 flex flex-wrap items-center gap-2">
              <span
                className={`rounded-full px-2.5 py-0.5 text-xs font-medium ${TYPE_BADGE_STYLES[account.type] ?? ""}`}
              >
                {TYPE_LABELS[account.type] ?? account.type}
              </span>
              <span className="text-xs text-muted">
                {BANK_LABELS[account.bank] ?? account.bank}
              </span>
              <span className="text-xs text-muted">&middot;</span>
              <span className="text-xs text-muted">{account.currency}</span>
            </div>
            <h1 className="text-2xl font-bold tracking-tight">
              {account.name}
            </h1>
            <p
              className={`mt-1 text-3xl font-bold tabular-nums ${
                balance >= 0 ? "text-foreground" : "text-danger"
              }`}
            >
              {formatAmount(account.balance, account.currency)}
            </p>
          </div>

          <div className="flex gap-2">
            <button
              onClick={() => setEditOpen(true)}
              className="rounded-lg border border-border px-4 py-2 text-sm font-medium text-foreground transition-colors hover:bg-card-hover"
            >
              <span className="flex items-center gap-2">
                <PencilIcon className="h-4 w-4" />
                Modifier
              </span>
            </button>
            <button
              onClick={() => setArchiveOpen(true)}
              className="rounded-lg border border-danger/30 px-4 py-2 text-sm font-medium text-danger transition-colors hover:bg-danger/10"
            >
              <span className="flex items-center gap-2">
                <ArchiveIcon className="h-4 w-4" />
                Archiver
              </span>
            </button>
          </div>
        </div>

        <div className="mt-4 flex flex-wrap items-center gap-6 border-t border-border pt-4 text-sm text-muted">
          <span>{account.transaction_count} transactions</span>
          <span className="inline-flex items-center gap-1.5">
            Solde initial :{" "}
            {editingBalance ? (
              <input
                type="number"
                step="0.01"
                value={balanceInput}
                onChange={(e) => setBalanceInput(e.target.value)}
                onBlur={saveInitialBalance}
                onKeyDown={handleBalanceKeyDown}
                autoFocus
                className="w-28 rounded border border-primary bg-background px-2 py-0.5 text-sm text-foreground outline-none"
              />
            ) : (
              <button
                onClick={startEditingBalance}
                className="inline-flex items-center gap-1 rounded px-1 py-0.5 text-foreground transition-colors hover:bg-card-hover"
                title="Modifier le solde initial"
              >
                {formatAmount(account.initial_balance, account.currency)}
                <PencilIcon className="h-3 w-3 text-muted" />
              </button>
            )}
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
              className="text-sm font-medium text-primary hover:text-primary-hover"
            >
              Voir tout
            </Link>
          )}
        </div>

        {transactions.length === 0 ? (
          <div className="rounded-xl border border-dashed border-border bg-card p-8 text-center text-sm text-muted">
            Aucune transaction pour ce compte.
          </div>
        ) : (
          <div className="overflow-hidden rounded-xl border border-border bg-card">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-border text-left text-xs text-muted">
                  <th className="px-4 py-3 font-medium">Date</th>
                  <th className="px-4 py-3 font-medium">Libellé</th>
                  <th className="px-4 py-3 font-medium">Catégorie</th>
                  <th className="px-4 py-3 text-right font-medium">Montant</th>
                </tr>
              </thead>
              <tbody>
                {transactions.map((tx) => {
                  const amt = parseFloat(tx.amount);
                  return (
                    <tr
                      key={tx.id}
                      className="border-b border-border last:border-0 hover:bg-card-hover"
                    >
                      <td className="whitespace-nowrap px-4 py-3 text-muted">
                        {formatDate(tx.date)}
                      </td>
                      <td className="px-4 py-3">{tx.label}</td>
                      <td className="px-4 py-3 text-muted">
                        {tx.category ? (
                          <span className="flex items-center gap-1.5">
                            <span
                              className="inline-block h-2 w-2 rounded-full"
                              style={{ backgroundColor: tx.category.color }}
                            />
                            {tx.category.name}
                          </span>
                        ) : (
                          <span className="text-muted/50">—</span>
                        )}
                      </td>
                      <td
                        className={`whitespace-nowrap px-4 py-3 text-right font-medium tabular-nums ${
                          amt >= 0 ? "text-success" : "text-danger"
                        }`}
                      >
                        {amt >= 0 ? "+" : ""}
                        {formatAmount(tx.amount, tx.currency)}
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
            className="flex items-center gap-2 rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white transition-colors hover:bg-primary-hover"
          >
            <UploadIcon className="h-4 w-4" />
            Importer un CSV
          </Link>
        </div>

        {imports.length === 0 ? (
          <div className="rounded-xl border border-dashed border-border bg-card p-8 text-center text-sm text-muted">
            Aucun import pour ce compte.
          </div>
        ) : (
          <div className="overflow-hidden rounded-xl border border-border bg-card">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-border text-left text-xs text-muted">
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
                    className="border-b border-border last:border-0 hover:bg-card-hover"
                  >
                    <td className="whitespace-nowrap px-4 py-3 text-muted">
                      {formatDate(imp.inserted_at)}
                    </td>
                    <td className="px-4 py-3 font-mono text-xs">
                      {imp.filename}
                    </td>
                    <td className="px-4 py-3 text-muted">
                      <span className="text-foreground">
                        {imp.rows_imported}
                      </span>
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
                      <span
                        className={`rounded-full px-2.5 py-0.5 text-xs font-medium ${
                          IMPORT_STATUS_STYLES[imp.status] ?? ""
                        }`}
                      >
                        {IMPORT_STATUS_LABELS[imp.status] ?? imp.status}
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>

      {/* ── Modals ─────────────────────────────────── */}
      <AccountForm
        key={editOpen ? `edit-${account.id}` : "closed"}
        open={editOpen}
        account={account}
        loading={editLoading}
        onSubmit={handleEdit}
        onClose={() => setEditOpen(false)}
      />

      <ConfirmDialog
        open={archiveOpen}
        title="Archiver ce compte ?"
        description="Le compte sera masqué de la liste. Les transactions existantes seront conservées. Cette action est réversible."
        confirmLabel="Archiver"
        variant="danger"
        loading={archiveLoading}
        onConfirm={handleArchive}
        onCancel={() => setArchiveOpen(false)}
      />
    </div>
  );
}

/* ── Back link ───────────────────────────────────────── */

function BackLink() {
  return (
    <Link
      href="/accounts"
      className="inline-flex items-center gap-1.5 text-sm text-muted transition-colors hover:text-foreground"
    >
      <ArrowLeftIcon className="h-4 w-4" />
      Comptes
    </Link>
  );
}

/* ── Loading skeleton ────────────────────────────────── */

function AccountDetailSkeleton() {
  return (
    <div className="space-y-6">
      <div className="h-4 w-16 animate-skeleton rounded bg-muted/20" />

      <div className="rounded-xl border border-border bg-card p-6">
        <div className="flex items-start justify-between">
          <div className="space-y-3">
            <div className="flex gap-2">
              <div className="h-5 w-16 animate-skeleton rounded-full bg-muted/20" />
              <div className="h-5 w-24 animate-skeleton rounded bg-muted/20" />
            </div>
            <div className="h-7 w-56 animate-skeleton rounded bg-muted/20" />
            <div className="h-9 w-36 animate-skeleton rounded bg-muted/20" />
          </div>
          <div className="flex gap-2">
            <div className="h-9 w-24 animate-skeleton rounded-lg bg-muted/20" />
            <div className="h-9 w-24 animate-skeleton rounded-lg bg-muted/20" />
          </div>
        </div>
        <div className="mt-4 flex gap-6 border-t border-border pt-4">
          <div className="h-4 w-28 animate-skeleton rounded bg-muted/20" />
          <div className="h-4 w-32 animate-skeleton rounded bg-muted/20" />
        </div>
      </div>

      <div>
        <div className="mb-3 h-6 w-44 animate-skeleton rounded bg-muted/20" />
        <div className="rounded-xl border border-border bg-card">
          {Array.from({ length: 5 }).map((_, i) => (
            <div
              key={i}
              className="flex items-center gap-6 border-b border-border px-4 py-4 last:border-0"
            >
              <div className="h-3 w-20 animate-skeleton rounded bg-muted/20" />
              <div className="h-3 w-40 animate-skeleton rounded bg-muted/20" />
              <div className="h-3 w-16 animate-skeleton rounded bg-muted/20" />
              <div className="ml-auto h-3 w-20 animate-skeleton rounded bg-muted/20" />
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

/* ── Icons ────────────────────────────────────────────── */

function ArrowLeftIcon({ className }: { className?: string }) {
  return (
    <svg
      className={className}
      fill="none"
      viewBox="0 0 24 24"
      stroke="currentColor"
      strokeWidth={2}
    >
      <path
        strokeLinecap="round"
        strokeLinejoin="round"
        d="M10.5 19.5 3 12m0 0 7.5-7.5M3 12h18"
      />
    </svg>
  );
}

function PencilIcon({ className }: { className?: string }) {
  return (
    <svg
      className={className}
      fill="none"
      viewBox="0 0 24 24"
      stroke="currentColor"
      strokeWidth={1.5}
    >
      <path
        strokeLinecap="round"
        strokeLinejoin="round"
        d="m16.862 4.487 1.687-1.688a1.875 1.875 0 1 1 2.652 2.652L10.582 16.07a4.5 4.5 0 0 1-1.897 1.13L6 18l.8-2.685a4.5 4.5 0 0 1 1.13-1.897l8.932-8.931Zm0 0L19.5 7.125M18 14v4.75A2.25 2.25 0 0 1 15.75 21H5.25A2.25 2.25 0 0 1 3 18.75V8.25A2.25 2.25 0 0 1 5.25 6H10"
      />
    </svg>
  );
}

function ArchiveIcon({ className }: { className?: string }) {
  return (
    <svg
      className={className}
      fill="none"
      viewBox="0 0 24 24"
      stroke="currentColor"
      strokeWidth={1.5}
    >
      <path
        strokeLinecap="round"
        strokeLinejoin="round"
        d="m20.25 7.5-.625 10.632a2.25 2.25 0 0 1-2.247 2.118H6.622a2.25 2.25 0 0 1-2.247-2.118L3.75 7.5M10 11.25h4M3.375 7.5h17.25c.621 0 1.125-.504 1.125-1.125v-1.5c0-.621-.504-1.125-1.125-1.125H3.375c-.621 0-1.125.504-1.125 1.125v1.5c0 .621.504 1.125 1.125 1.125Z"
      />
    </svg>
  );
}

function UploadIcon({ className }: { className?: string }) {
  return (
    <svg
      className={className}
      fill="none"
      viewBox="0 0 24 24"
      stroke="currentColor"
      strokeWidth={2}
    >
      <path
        strokeLinecap="round"
        strokeLinejoin="round"
        d="M3 16.5v2.25A2.25 2.25 0 0 0 5.25 21h13.5A2.25 2.25 0 0 0 21 18.75V16.5m-13.5-9L12 3m0 0 4.5 4.5M12 3v13.5"
      />
    </svg>
  );
}
