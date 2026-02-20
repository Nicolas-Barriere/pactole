"use client";

import { useState } from "react";
import type { Account, Tag } from "@/types";
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
  const selectedAccountLabel = form.account_id
    ? (accounts.find((a) => a.id === form.account_id)?.name ?? "Compte inconnu")
    : "Sélectionner un compte";

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

  return (
    <Dialog open={open} onOpenChange={(o) => !o && onClose()}>
      <DialogContent className="max-w-lg">
        <DialogHeader>
          <DialogTitle>Nouvelle transaction</DialogTitle>
        </DialogHeader>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-1.5">
              <Label htmlFor="tx-date">Date</Label>
              <Input
                id="tx-date"
                type="date"
                value={form.date}
                onChange={(e) => setForm({ ...form, date: e.target.value })}
                className={errors.date ? "border-destructive" : ""}
              />
              {errors.date && (
                <p className="text-xs text-destructive">{errors.date}</p>
              )}
            </div>

            <div className="space-y-1.5">
              <Label htmlFor="tx-amount">Montant</Label>
              <Input
                id="tx-amount"
                type="number"
                step="0.01"
                value={form.amount}
                onChange={(e) => setForm({ ...form, amount: e.target.value })}
                placeholder="-42.50"
                className={errors.amount ? "border-destructive" : ""}
              />
              {errors.amount && (
                <p className="text-xs text-destructive">{errors.amount}</p>
              )}
            </div>
          </div>

          <div className="space-y-1.5">
            <Label htmlFor="tx-label">Libellé</Label>
            <Input
              id="tx-label"
              value={form.label}
              onChange={(e) => setForm({ ...form, label: e.target.value })}
              placeholder="Ex: Courses Carrefour"
              className={errors.label ? "border-destructive" : ""}
            />
            {errors.label && (
              <p className="text-xs text-destructive">{errors.label}</p>
            )}
          </div>

          <div className="space-y-1.5">
            <Label>Compte</Label>
            <Select
              value={form.account_id}
              onValueChange={(v) => setForm({ ...form, account_id: v ?? "" })}
            >
              <SelectTrigger
                className={errors.account_id ? "border-destructive" : ""}
              >
                <SelectValue>{selectedAccountLabel}</SelectValue>
              </SelectTrigger>
              <SelectContent>
                {accounts.map((a) => (
                  <SelectItem key={a.id} value={a.id}>
                    {a.name}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
            {errors.account_id && (
              <p className="text-xs text-destructive">{errors.account_id}</p>
            )}
          </div>

          <div className="space-y-1.5">
            <Label>
              Tags{" "}
              <span className="font-normal text-muted-foreground">(optionnel)</span>
            </Label>
            <div className="flex flex-wrap gap-2">
              {tags.map((t) => {
                const selected = form.tag_ids.includes(t.id);
                return (
                  <button
                    key={t.id}
                    type="button"
                    onClick={() => toggleTag(t.id)}
                    className={`inline-flex items-center gap-1.5 border px-3 py-1 text-xs font-medium transition-colors ${
                      selected
                        ? "border-primary bg-primary/10 text-primary"
                        : "border-border text-muted-foreground hover:border-primary/30 hover:text-foreground"
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
                <span className="text-xs text-muted-foreground">
                  Aucun tag disponible
                </span>
              )}
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
              {loading ? "Enregistrement..." : "Ajouter"}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
