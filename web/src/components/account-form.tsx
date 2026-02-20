"use client";

import { useState } from "react";
import type { Account, AccountType } from "@/types";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import type { BadgeProps } from "@/components/ui/badge";

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

export const TYPE_BADGE_VARIANT: Record<string, BadgeProps["variant"]> = {
  checking: "default",
  savings: "success",
  brokerage: "warning",
  crypto: "secondary",
};

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

  const isEdit = !!account;

  return (
    <Dialog open={open} onOpenChange={(o) => !o && onClose?.()}>
      <DialogContent className="max-w-lg">
        <DialogHeader>
          <DialogTitle>
            {isEdit ? "Modifier le compte" : "Nouveau compte"}
          </DialogTitle>
        </DialogHeader>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div className="space-y-1.5">
            <Label htmlFor="acc-name">Nom</Label>
            <Input
              id="acc-name"
              value={form.name}
              onChange={(e) => setForm({ ...form, name: e.target.value })}
              placeholder="Ex: Compte courant Boursorama"
              className={errors.name ? "border-destructive" : ""}
            />
            {errors.name && (
              <p className="text-xs text-destructive">{errors.name}</p>
            )}
          </div>

          <div className="space-y-1.5">
            <Label>Banque</Label>
            <Select
              value={form.bank}
              onValueChange={(v) => setForm({ ...form, bank: v ?? "" })}
            >
              <SelectTrigger className={errors.bank ? "border-destructive" : ""}>
                <SelectValue placeholder="Sélectionner une banque" />
              </SelectTrigger>
              <SelectContent>
                {BANKS.map((b) => (
                  <SelectItem key={b.value} value={b.value}>
                    {b.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
            {errors.bank && (
              <p className="text-xs text-destructive">{errors.bank}</p>
            )}
          </div>

          <div className="space-y-1.5">
            <Label>Type</Label>
            <Select
              value={form.type}
              onValueChange={(v) =>
                setForm({ ...form, type: (v ?? "checking") as AccountType })
              }
            >
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {ACCOUNT_TYPES.map((t) => (
                  <SelectItem key={t.value} value={t.value}>
                    {t.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-1.5">
              <Label htmlFor="acc-balance">Solde initial</Label>
              <Input
                id="acc-balance"
                type="number"
                step="0.01"
                value={form.initial_balance}
                onChange={(e) =>
                  setForm({ ...form, initial_balance: e.target.value })
                }
              />
            </div>

            <div className="space-y-1.5">
              <Label htmlFor="acc-currency">Devise</Label>
              <Input
                id="acc-currency"
                value={form.currency}
                onChange={(e) =>
                  setForm({ ...form, currency: e.target.value.toUpperCase() })
                }
                maxLength={3}
              />
            </div>
          </div>

          <DialogFooter className="pt-2">
            <Button
              type="button"
              variant="outline"
              onClick={onClose}
              disabled={loading}
            >
              Annuler
            </Button>
            <Button type="submit" disabled={loading}>
              {loading ? "Enregistrement..." : isEdit ? "Enregistrer" : "Créer"}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
