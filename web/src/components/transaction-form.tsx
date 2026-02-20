"use client";

import { useState } from "react";
import type { Account, Tag } from "@/types";

export interface TransactionFormData {
  date: string;
  label: string;
  amount: string;
  tag_ids: string[];
  account_id: string;
}

interface TransactionFormProps {
  open: boolean;
  accounts: Account[];
  tags: Tag[];
  defaultAccountId?: string;
  loading?: boolean;
  onSubmit: (data: TransactionFormData) => void;
  onClose: () => void;
}

function todayISO() {
  return new Date().toISOString().slice(0, 10);
}

export function TransactionForm({
  open,
  accounts,
  tags,
  defaultAccountId = "",
  loading = false,
  onSubmit,
  onClose,
}: TransactionFormProps) {
  const [form, setForm] = useState<TransactionFormData>({
    date: todayISO(),
    label: "",
    amount: "",
    tag_ids: [],
    account_id: defaultAccountId,
  });
  const [errors, setErrors] = useState<Partial<Record<string, string>>>({});

  function validate(): boolean {
    const errs: Partial<Record<string, string>> = {};
    if (!form.label.trim()) errs.label = "Le libellé est requis";
    if (!form.amount || isNaN(parseFloat(form.amount)))
      errs.amount = "Le montant est requis";
    if (!form.account_id) errs.account_id = "Le compte est requis";
    if (!form.date) errs.date = "La date est requise";
    setErrors(errs);
    return Object.keys(errs).length === 0;
  }

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (validate()) onSubmit(form);
  }

  function toggleTag(tagId: string) {
    setForm((prev) => ({
      ...prev,
      tag_ids: prev.tag_ids.includes(tagId)
        ? prev.tag_ids.filter((id) => id !== tagId)
        : [...prev.tag_ids, tagId],
    }));
  }

  if (!open) return null;

  const inputBase =
    "w-full rounded-lg border bg-background px-3 py-2 text-sm outline-none transition-colors focus:border-primary";

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center">
      <div
        className="fixed inset-0 bg-black/60 backdrop-blur-sm"
        onClick={onClose}
      />
      <div className="relative z-10 w-full max-w-lg rounded-xl border border-border bg-card p-6 shadow-2xl">
        <h2 className="text-lg font-semibold">Nouvelle transaction</h2>

        <form onSubmit={handleSubmit} className="mt-4 space-y-4">
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="mb-1 block text-sm font-medium">Date</label>
              <input
                type="date"
                value={form.date}
                onChange={(e) => setForm({ ...form, date: e.target.value })}
                className={`${inputBase} ${errors.date ? "border-danger" : "border-border"}`}
              />
              {errors.date && (
                <p className="mt-1 text-xs text-danger">{errors.date}</p>
              )}
            </div>

            <div>
              <label className="mb-1 block text-sm font-medium">Montant</label>
              <input
                type="number"
                step="0.01"
                value={form.amount}
                onChange={(e) => setForm({ ...form, amount: e.target.value })}
                placeholder="-42.50"
                className={`${inputBase} ${errors.amount ? "border-danger" : "border-border"}`}
              />
              {errors.amount && (
                <p className="mt-1 text-xs text-danger">{errors.amount}</p>
              )}
            </div>
          </div>

          <div>
            <label className="mb-1 block text-sm font-medium">Libellé</label>
            <input
              type="text"
              value={form.label}
              onChange={(e) => setForm({ ...form, label: e.target.value })}
              placeholder="Ex: Courses Carrefour"
              className={`${inputBase} ${errors.label ? "border-danger" : "border-border"}`}
            />
            {errors.label && (
              <p className="mt-1 text-xs text-danger">{errors.label}</p>
            )}
          </div>

          <div>
            <label className="mb-1 block text-sm font-medium">Compte</label>
            <select
              value={form.account_id}
              onChange={(e) =>
                setForm({ ...form, account_id: e.target.value })
              }
              className={`${inputBase} ${errors.account_id ? "border-danger" : "border-border"}`}
            >
              <option value="">Sélectionner un compte</option>
              {accounts.map((a) => (
                <option key={a.id} value={a.id}>
                  {a.name}
                </option>
              ))}
            </select>
            {errors.account_id && (
              <p className="mt-1 text-xs text-danger">{errors.account_id}</p>
            )}
          </div>

          <div>
            <label className="mb-1 block text-sm font-medium">
              Tags{" "}
              <span className="font-normal text-muted">(optionnel)</span>
            </label>
            <div className="flex flex-wrap gap-2">
              {tags.map((t) => {
                const selected = form.tag_ids.includes(t.id);
                return (
                  <button
                    key={t.id}
                    type="button"
                    onClick={() => toggleTag(t.id)}
                    className={`inline-flex items-center gap-1.5 rounded-full border px-3 py-1 text-xs font-medium transition-colors ${
                      selected
                        ? "border-primary bg-primary/10 text-primary"
                        : "border-border text-muted hover:border-primary/30 hover:text-foreground"
                    }`}
                  >
                    <span
                      className="inline-block h-2 w-2 rounded-full"
                      style={{ backgroundColor: t.color }}
                    />
                    {t.name}
                  </button>
                );
              })}
              {tags.length === 0 && (
                <span className="text-xs text-muted">Aucun tag disponible</span>
              )}
            </div>
          </div>

          <div className="flex justify-end gap-3 pt-2">
            <button
              type="button"
              onClick={onClose}
              disabled={loading}
              className="rounded-lg border border-border px-4 py-2 text-sm font-medium text-muted transition-colors hover:bg-card-hover hover:text-foreground disabled:opacity-50"
            >
              Annuler
            </button>
            <button
              type="submit"
              disabled={loading}
              className="rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white transition-colors hover:bg-primary-hover disabled:opacity-50"
            >
              {loading ? "Enregistrement..." : "Ajouter"}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
