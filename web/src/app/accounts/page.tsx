"use client";

import { useEffect, useState, useCallback } from "react";
import Link from "next/link";
import { api, ApiError } from "@/lib/api";
import { useToast } from "@/components/toast";
import {
  AccountForm,
  BANK_LABELS,
  TYPE_LABELS,
  TYPE_BADGE_STYLES,
  type AccountFormData,
} from "@/components/account-form";
import type { Account } from "@/types";

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

export default function AccountsPage() {
  const toast = useToast();
  const [accounts, setAccounts] = useState<Account[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchAccounts = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const data = await api.get<Account[]>("/accounts");
      setAccounts(data);
    } catch (err) {
      setError(
        err instanceof ApiError
          ? "Impossible de charger les comptes"
          : "Erreur de connexion",
      );
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchAccounts();
  }, [fetchAccounts]);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold tracking-tight">Comptes</h1>
          <p className="text-sm text-muted">Gérez vos comptes bancaires</p>
        </div>
        <Link
          href="/accounts/new"
          className="rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white transition-colors hover:bg-primary-hover"
        >
          <span className="flex items-center gap-2">
            <PlusIcon className="h-4 w-4" />
            Ajouter un compte
          </span>
        </Link>
      </div>

      {loading && <AccountListSkeleton />}

      {error && (
        <div className="rounded-xl border border-danger/30 bg-danger/5 p-6 text-center">
          <p className="text-sm text-danger">{error}</p>
          <button
            onClick={fetchAccounts}
            className="mt-3 text-sm font-medium text-primary hover:text-primary-hover"
          >
            Réessayer
          </button>
        </div>
      )}

      {!loading && !error && accounts.length === 0 && (
        <div className="rounded-xl border border-dashed border-border bg-card p-12 text-center">
          <BankIcon className="mx-auto mb-3 h-10 w-10 text-muted/50" />
          <p className="text-sm text-muted">
            Aucun compte pour le moment.
          </p>
          <Link
            href="/accounts/new"
            className="mt-3 inline-block text-sm font-medium text-primary hover:text-primary-hover"
          >
            Créer votre premier compte
          </Link>
        </div>
      )}

      {!loading && !error && accounts.length > 0 && (
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
      className="group rounded-xl border border-border bg-card p-5 transition-colors hover:border-primary/30 hover:bg-card-hover"
    >
      <div className="mb-3 flex items-center justify-between">
        <span
          className={`rounded-full px-2.5 py-0.5 text-xs font-medium ${TYPE_BADGE_STYLES[account.type] ?? ""}`}
        >
          {TYPE_LABELS[account.type] ?? account.type}
        </span>
        <span className="text-xs text-muted">
          {BANK_LABELS[account.bank] ?? account.bank}
        </span>
      </div>

      <h3 className="mb-1 font-semibold tracking-tight group-hover:text-primary">
        {account.name}
      </h3>

      <p
        className={`text-2xl font-bold tabular-nums ${balance >= 0 ? "text-foreground" : "text-danger"
          }`}
      >
        {formatAmount(account.balance, account.currency)}
      </p>

      <div className="mt-3 flex items-center justify-between text-xs text-muted">
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

/* ── Loading skeleton ────────────────────────────────── */

function AccountListSkeleton() {
  return (
    <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
      {Array.from({ length: 3 }).map((_, i) => (
        <div
          key={i}
          className="rounded-xl border border-border bg-card p-5"
        >
          <div className="mb-3 flex items-center justify-between">
            <div className="h-5 w-16 animate-skeleton rounded-full bg-muted/20" />
            <div className="h-3 w-20 animate-skeleton rounded bg-muted/20" />
          </div>
          <div className="mb-1 h-5 w-40 animate-skeleton rounded bg-muted/20" />
          <div className="h-8 w-28 animate-skeleton rounded bg-muted/20" />
          <div className="mt-3 flex justify-between">
            <div className="h-3 w-24 animate-skeleton rounded bg-muted/20" />
            <div className="h-3 w-28 animate-skeleton rounded bg-muted/20" />
          </div>
        </div>
      ))}
    </div>
  );
}

/* ── Icons ────────────────────────────────────────────── */

function PlusIcon({ className }: { className?: string }) {
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
        d="M12 4.5v15m7.5-7.5h-15"
      />
    </svg>
  );
}

function BankIcon({ className }: { className?: string }) {
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
        d="M12 21v-8.25M15.75 21v-8.25M8.25 21v-8.25M3 9l9-6 9 6m-1.5 12V10.332A48.36 48.36 0 0 0 12 9.75c-2.551 0-5.056.2-7.5.582V21M3 21h18M12 6.75h.008v.008H12V6.75Z"
      />
    </svg>
  );
}
