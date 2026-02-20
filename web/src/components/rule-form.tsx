"use client";

import { useState } from "react";
import type { TaggingRule, Tag } from "@/types";
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

export interface RuleFormData {
  keyword: string;
  tag_id: string;
  priority: number;
}

interface RuleFormProps {
  open: boolean;
  rule?: TaggingRule | null;
  tags: Tag[];
  loading?: boolean;
  onSubmit: (data: RuleFormData) => void;
  onClose: () => void;
}

function initialFormData(rule?: TaggingRule | null): RuleFormData {
  if (rule) {
    return {
      keyword: rule.keyword,
      tag_id: rule.tag_id,
      priority: rule.priority,
    };
  }
  return { keyword: "", tag_id: "", priority: 0 };
}

export function RuleForm({
  open,
  rule,
  tags,
  loading = false,
  onSubmit,
  onClose,
}: RuleFormProps) {
  const [form, setForm] = useState<RuleFormData>(() => initialFormData(rule));
  const [errors, setErrors] = useState<
    Partial<Record<keyof RuleFormData, string>>
  >({});

  function validate(): boolean {
    const newErrors: Partial<Record<keyof RuleFormData, string>> = {};
    if (!form.keyword.trim()) newErrors.keyword = "Le mot-clé est requis";
    if (!form.tag_id) newErrors.tag_id = "Le tag est requis";
    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  }

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (validate()) onSubmit(form);
  }

  const isEdit = !!rule;

  return (
    <Dialog open={open} onOpenChange={(o) => !o && onClose()}>
      <DialogContent className="max-w-md">
        <DialogHeader>
          <DialogTitle>
            {isEdit ? "Modifier la règle" : "Nouvelle règle"}
          </DialogTitle>
        </DialogHeader>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div className="space-y-1.5">
            <Label htmlFor="rule-keyword">Mot-clé</Label>
            <Input
              id="rule-keyword"
              value={form.keyword}
              onChange={(e) => setForm({ ...form, keyword: e.target.value })}
              placeholder="Ex: CARREFOUR"
              className={errors.keyword ? "border-destructive" : ""}
            />
            <p className="text-xs text-muted-foreground">
              Le mot-clé sera recherché (sans tenir compte de la casse) dans le
              libellé des transactions.
            </p>
            {errors.keyword && (
              <p className="text-xs text-destructive">{errors.keyword}</p>
            )}
          </div>

          <div className="space-y-1.5">
            <Label>Tag</Label>
            <Select
              value={form.tag_id}
              onValueChange={(v) => setForm({ ...form, tag_id: v ?? "" })}
            >
              <SelectTrigger className={errors.tag_id ? "border-destructive" : ""}>
                <SelectValue placeholder="Sélectionner un tag" />
              </SelectTrigger>
              <SelectContent>
                {tags.map((t) => (
                  <SelectItem key={t.id} value={t.id}>
                    {t.name}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
            {errors.tag_id && (
              <p className="text-xs text-destructive">{errors.tag_id}</p>
            )}
          </div>

          <div className="space-y-1.5">
            <Label htmlFor="rule-priority">Priorité</Label>
            <Input
              id="rule-priority"
              type="number"
              value={form.priority}
              onChange={(e) =>
                setForm({ ...form, priority: parseInt(e.target.value, 10) || 0 })
              }
              placeholder="0"
            />
            <p className="text-xs text-muted-foreground">
              Une priorité plus élevée (ex: 10) sera appliquée avant une priorité
              plus basse (ex: 0).
            </p>
          </div>

          <DialogFooter className="pt-2">
            <Button type="button" variant="outline" onClick={onClose} disabled={loading}>
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
