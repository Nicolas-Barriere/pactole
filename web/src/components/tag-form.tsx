"use client";

import { useState } from "react";
import type { Tag } from "@/types";

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
  if (tag) {
    return {
      name: tag.name,
      color: tag.color,
    };
  }
  return { name: "", color: "#3B82F6" };
}

export function TagForm({
  open,
  tag,
  loading = false,
  onSubmit,
  onClose,
}: TagFormProps) {
  const [form, setForm] = useState<TagFormData>(() =>
    initialFormData(tag),
  );
  const [errors, setErrors] = useState<
    Partial<Record<keyof TagFormData, string>>
  >({});

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

  if (!open) return null;

  const isEdit = !!tag;
  const inputBase =
    "w-full rounded-lg border bg-background px-3 py-2 text-sm outline-none transition-colors focus:border-primary";

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center">
      <div
        className="fixed inset-0 bg-black/60 backdrop-blur-sm"
        onClick={onClose}
      />
      <div className="relative z-10 w-full max-w-md rounded-xl border border-border bg-card p-6 shadow-2xl">
        <h2 className="text-lg font-semibold">
          {isEdit ? "Modifier le tag" : "Nouveau tag"}
        </h2>

        <form onSubmit={handleSubmit} className="mt-4 space-y-4">
          <div>
            <label className="mb-1 block text-sm font-medium">Nom</label>
            <input
              type="text"
              value={form.name}
              onChange={(e) => setForm({ ...form, name: e.target.value })}
              className={`${inputBase} ${errors.name ? "border-danger" : "border-border"}`}
              placeholder="Ex: Alimentation"
            />
            {errors.name && (
              <p className="mt-1 text-xs text-danger">{errors.name}</p>
            )}
          </div>

          <div>
            <label className="mb-1 block text-sm font-medium">Couleur</label>
            <div className="flex items-center gap-3">
              <input
                type="color"
                value={form.color}
                onChange={(e) => setForm({ ...form, color: e.target.value })}
                className="h-10 w-14 cursor-pointer rounded border border-border bg-transparent p-1"
              />
              <input
                type="text"
                value={form.color}
                onChange={(e) => setForm({ ...form, color: e.target.value })}
                className={`${inputBase} ${errors.color ? "border-danger" : "border-border"} flex-1 uppercase`}
                placeholder="#000000"
                maxLength={7}
              />
            </div>
            {errors.color && (
              <p className="mt-1 text-xs text-danger">{errors.color}</p>
            )}
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
              {loading
                ? "Enregistrement..."
                : isEdit
                  ? "Enregistrer"
                  : "Créer"}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
