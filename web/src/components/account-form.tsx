"use client";

import { useState } from "react";
import type { Account, AccountType } from "@/types";

/* ── Shared constants ────────────────────────────────── */

export const BANKS: { value: string; label: string }[] = [
  { value: "boursorama", label: "Boursorama" },
  { value: "revolut", label: "Revolut" },
  { value: "caisse_depargne", label: "Caisse d'Épargne" },
];

export const BANK_LABELS: Record<string, string> = Object.fromEntries(
  BANKS.map((b) => [b.value, b.label]),
);

export const ACCOUNT_TYPES: { value: AccountType; label: string }[] = [
  { value: "checking", label: "Courant" },
  { value: "savings", label: "Épargne" },
  { value: "brokerage", label: "Bourse" },
  { value: "crypto", label: "Crypto" },
];

export const TYPE_LABELS: Record<string, string> = Object.fromEntries(
  ACCOUNT_TYPES.map((t) => [t.value, t.label]),
);

export const TYPE_BADGE_STYLES: Record<string, string> = {
  checking: "bg-primary/15 text-primary",
  savings: "bg-success/15 text-success",
  brokerage: "bg-warning/15 text-warning",
  crypto: "bg-purple-500/15 text-purple-400",
};

/* ── Form types ──────────────────────────────────────── */

export interface AccountFormData {
  name: string;
  bank: string;
  type: AccountType;
  initial_balance: string;
  currency: string;
}

interface AccountFormProps {
  open?: boolean;
  account?: Account | null;
  loading?: boolean;
  asModal?: boolean;
  initialBank?: string;
  onSubmit: (data: AccountFormData) => void;
  onClose?: () => void;
}

/* ── Component ───────────────────────────────────────── */

function initialFormData(account?: Account | null, initialBank?: string): AccountFormData {
  if (account) {
    return {
      name: account.name,
      bank: account.bank,
      type: account.type,
      initial_balance: account.initial_balance,
      currency: account.currency,
    };
  }
  return { name: "", bank: initialBank || "", type: "checking", initial_balance: "0", currency: "EUR" };
}

export function AccountForm({
  open = true,
  account,
  loading = false,
  asModal = true,
  initialBank,
  onSubmit,
  onClose,
}: AccountFormProps) {
  const [form, setForm] = useState<AccountFormData>(() =>
    initialFormData(account, initialBank),
  );
  const [errors, setErrors] = useState<
    Partial<Record<keyof AccountFormData, string>>
  >({});

  function validate(): boolean {
    const newErrors: Partial<Record<keyof AccountFormData, string>> = {};
    if (!form.name.trim()) newErrors.name = "Le nom est requis";
    if (!form.bank) newErrors.bank = "La banque est requise";
    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  }

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (validate()) onSubmit(form);
  }

  if (!open) return null;

  const isEdit = !!account;
  const inputBase =
    "w-full rounded-lg border bg-background px-3 py-2 text-sm outline-none transition-colors focus:border-primary";

  const formContent = (
    <div className={`relative z-10 w-full max-w-lg rounded-xl border border-border bg-card p-6 shadow-2xl ${!asModal ? "mx-auto mt-8" : ""
      }`}>
      <h2 className="text-lg font-semibold">
        {isEdit ? "Modifier le compte" : "Nouveau compte"}
      </h2>

      <form onSubmit={handleSubmit} className="mt-4 space-y-4">
        <div>
          <label className="mb-1 block text-sm font-medium">Nom</label>
          <input
            type="text"
            value={form.name}
            onChange={(e) => setForm({ ...form, name: e.target.value })}
            className={`${inputBase} ${errors.name ? "border-danger" : "border-border"}`}
            placeholder="Ex: Compte courant Boursorama"
          />
          {errors.name && (
            <p className="mt-1 text-xs text-danger">{errors.name}</p>
          )}
        </div>

        <div>
          <label className="mb-1 block text-sm font-medium">Banque</label>
          <select
            value={form.bank}
            onChange={(e) => setForm({ ...form, bank: e.target.value })}
            className={`${inputBase} ${errors.bank ? "border-danger" : "border-border"}`}
          >
            <option value="">Sélectionner une banque</option>
            {BANKS.map((b) => (
              <option key={b.value} value={b.value}>
                {b.label}
              </option>
            ))}
          </select>
          {errors.bank && (
            <p className="mt-1 text-xs text-danger">{errors.bank}</p>
          )}
        </div>

        <div>
          <label className="mb-1 block text-sm font-medium">Type</label>
          <select
            value={form.type}
            onChange={(e) =>
              setForm({ ...form, type: e.target.value as AccountType })
            }
            className={`${inputBase} border-border`}
          >
            {ACCOUNT_TYPES.map((t) => (
              <option key={t.value} value={t.value}>
                {t.label}
              </option>
            ))}
          </select>
        </div>

        <div className="grid grid-cols-2 gap-4">
          <div>
            <label className="mb-1 block text-sm font-medium">
              Solde initial
            </label>
            <input
              type="number"
              step="0.01"
              value={form.initial_balance}
              onChange={(e) =>
                setForm({ ...form, initial_balance: e.target.value })
              }
              className={`${inputBase} border-border`}
            />
          </div>

          <div>
            <label className="mb-1 block text-sm font-medium">Devise</label>
            <input
              type="text"
              value={form.currency}
              onChange={(e) =>
                setForm({ ...form, currency: e.target.value.toUpperCase() })
              }
              className={`${inputBase} border-border`}
              maxLength={3}
            />
          </div>
        </div>

        <div className="flex justify-end gap-3 pt-2">
          {onClose && (
            <button
              type="button"
              onClick={onClose}
              disabled={loading}
              className="rounded-lg border border-border px-4 py-2 text-sm font-medium text-muted transition-colors hover:bg-card-hover hover:text-foreground disabled:opacity-50"
            >
              Annuler
            </button>
          )}
          <button
            type="submit"
            disabled={loading}
            className="rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white transition-colors hover:bg-primary-hover disabled:opacity-50"
          >
            {loading
              ? "Enregistrement..."
              : isEdit
                ? "Enregistrer"
                : "Créer"}
          </button>
        </div>
      </form>
    </div>
  );

  if (!asModal) return formContent;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center">
      <div
        className="fixed inset-0 bg-black/60 backdrop-blur-sm"
        onClick={onClose}
      />
      {formContent}
    </div>
  );
}
