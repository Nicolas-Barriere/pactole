"use client";

import { useState } from "react";
import type { Tag } from "@/types";
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

export interface TagFormData {
  name: string;
  color: string;
}

interface TagFormProps {
  open: boolean;
  tag?: Tag | null;
  loading?: boolean;
  onSubmit: (data: TagFormData) => void;
  onClose: () => void;
}

function initialFormData(tag?: Tag | null): TagFormData {
  if (tag) return { name: tag.name, color: tag.color };
  return { name: "", color: "#3B82F6" };
}

export function TagForm({
  open,
  tag,
  loading = false,
  onSubmit,
  onClose,
}: TagFormProps) {
  const [form, setForm] = useState<TagFormData>(() => initialFormData(tag));
  const [errors, setErrors] = useState<Partial<Record<keyof TagFormData, string>>>({});

  function validate(): boolean {
    const newErrors: Partial<Record<keyof TagFormData, string>> = {};
    if (!form.name.trim()) newErrors.name = "Le nom est requis";
    if (!form.color.trim()) newErrors.color = "La couleur est requise";
    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  }

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (validate()) onSubmit(form);
  }

  const isEdit = !!tag;

  return (
    <Dialog open={open} onOpenChange={(o) => !o && onClose()}>
      <DialogContent className="max-w-md">
        <DialogHeader>
          <DialogTitle>{isEdit ? "Modifier le tag" : "Nouveau tag"}</DialogTitle>
        </DialogHeader>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div className="space-y-1.5">
            <Label htmlFor="tag-name">Nom</Label>
            <Input
              id="tag-name"
              value={form.name}
              onChange={(e) => setForm({ ...form, name: e.target.value })}
              placeholder="Ex: Alimentation"
              className={errors.name ? "border-destructive" : ""}
            />
            {errors.name && (
              <p className="text-xs text-destructive">{errors.name}</p>
            )}
          </div>

          <div className="space-y-1.5">
            <Label>Couleur</Label>
            <div className="flex items-center gap-3">
              <input
                type="color"
                value={form.color}
                onChange={(e) => setForm({ ...form, color: e.target.value })}
                className="h-10 w-14 cursor-pointer border border-border bg-transparent p-1"
              />
              <Input
                value={form.color}
                onChange={(e) => setForm({ ...form, color: e.target.value })}
                placeholder="#000000"
                maxLength={7}
                className={`uppercase ${errors.color ? "border-destructive" : ""}`}
              />
            </div>
            {errors.color && (
              <p className="text-xs text-destructive">{errors.color}</p>
            )}
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
