"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Pencil, Trash2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { TagForm, type TagFormData } from "@/components/tag-form";
import { RuleForm, type RuleFormData } from "@/components/rule-form";
import { ConfirmDialog } from "@/components/confirm-dialog";
import {
  createTag,
  updateTag,
  deleteTag,
  createRule,
  updateRule,
  deleteRule,
  reapplyRules,
} from "@/app/actions/tags";
import type { Tag, TaggingRule } from "@/types";

interface TagsManagerProps {
  initialTags: Tag[];
  initialRules: TaggingRule[];
}

export function TagsManager({ initialTags, initialRules }: TagsManagerProps) {
  const router = useRouter();
  const [isPending, startTransition] = useTransition();

  /* Tag form state */
  const [tagFormOpen, setTagFormOpen] = useState(false);
  const [editingTag, setEditingTag] = useState<Tag | null>(null);
  const [tagDeleteId, setTagDeleteId] = useState<string | null>(null);

  /* Rule form state */
  const [ruleFormOpen, setRuleFormOpen] = useState(false);
  const [editingRule, setEditingRule] = useState<TaggingRule | null>(null);
  const [ruleDeleteId, setRuleDeleteId] = useState<string | null>(null);

  function refresh() {
    router.refresh();
  }

  /* ── Tag handlers ──────────────────────────────────── */

  function openAddTag() {
    setEditingTag(null);
    setTagFormOpen(true);
  }

  function openEditTag(tag: Tag) {
    setEditingTag(tag);
    setTagFormOpen(true);
  }

  function handleSaveTag(data: TagFormData) {
    startTransition(async () => {
      const result = editingTag
        ? await updateTag(editingTag.id, data)
        : await createTag(data);

      if (result.success) {
        toast.success(editingTag ? "Tag modifié" : "Tag créé");
        setTagFormOpen(false);
        refresh();
      } else {
        toast.error(result.error);
      }
    });
  }

  function handleDeleteTag() {
    if (!tagDeleteId) return;
    startTransition(async () => {
      const result = await deleteTag(tagDeleteId);
      if (result.success) {
        toast.success("Tag supprimé");
        setTagDeleteId(null);
        refresh();
      } else {
        toast.error(result.error);
        setTagDeleteId(null);
      }
    });
  }

  /* ── Rule handlers ─────────────────────────────────── */

  function openAddRule() {
    setEditingRule(null);
    setRuleFormOpen(true);
  }

  function openEditRule(rule: TaggingRule) {
    setEditingRule(rule);
    setRuleFormOpen(true);
  }

  function handleSaveRule(data: RuleFormData) {
    startTransition(async () => {
      const result = editingRule
        ? await updateRule(editingRule.id, data)
        : await createRule(data);

      if (result.success) {
        toast.success(editingRule ? "Règle modifiée" : "Règle créée");
        setRuleFormOpen(false);
        refresh();
      } else {
        toast.error(result.error);
      }
    });
  }

  function handleDeleteRule() {
    if (!ruleDeleteId) return;
    startTransition(async () => {
      const result = await deleteRule(ruleDeleteId);
      if (result.success) {
        toast.success("Règle supprimée");
        setRuleDeleteId(null);
        refresh();
      } else {
        toast.error(result.error);
        setRuleDeleteId(null);
      }
    });
  }

  function handleReapplyRules() {
    startTransition(async () => {
      const result = await reapplyRules();
      if (result.success && result.data) {
        toast.success(`${result.data.tagged_count} transactions taguées avec succès`);
      } else if (!result.success) {
        toast.error(result.error);
      }
    });
  }

  return (
    <div className="space-y-10">
      {/* ── Tags ─────────────────────────────────────── */}
      <section>
        <div className="mb-4 flex items-center justify-between">
          <h2 className="text-lg font-semibold tracking-tight">Tags</h2>
          <Button size="sm" onClick={openAddTag}>
            Ajouter
          </Button>
        </div>

        <div className="grid gap-3 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4">
          {initialTags.map((tag) => (
            <div
              key={tag.id}
              className="group flex items-center justify-between border border-border bg-card p-3 transition-colors hover:border-primary/30 hover:bg-accent"
            >
              <div className="flex items-center gap-3 truncate">
                <div
                  className="h-4 w-4 shrink-0 rounded-full"
                  style={{ backgroundColor: tag.color }}
                />
                <span className="truncate font-medium">{tag.name}</span>
              </div>
              <div className="flex items-center gap-1 opacity-0 transition-opacity group-hover:opacity-100">
                <button
                  onClick={() => openEditTag(tag)}
                  className="p-1.5 text-muted-foreground hover:bg-background hover:text-foreground"
                  title="Modifier"
                >
                  <Pencil className="h-4 w-4" />
                </button>
                <button
                  onClick={() => setTagDeleteId(tag.id)}
                  className="p-1.5 text-muted-foreground hover:bg-destructive/10 hover:text-destructive"
                  title="Supprimer"
                >
                  <Trash2 className="h-4 w-4" />
                </button>
              </div>
            </div>
          ))}
          {initialTags.length === 0 && (
            <div className="col-span-full border border-dashed border-border p-6 text-center text-sm text-muted-foreground">
              Aucun tag configuré
            </div>
          )}
        </div>
      </section>

      {/* ── Rules ────────────────────────────────────── */}
      <section>
        <div className="mb-4 flex items-center justify-between">
          <h2 className="text-lg font-semibold tracking-tight">
            Règles d&apos;auto-tagging
          </h2>
          <div className="flex gap-2">
            <Button
              variant="outline"
              size="sm"
              onClick={handleReapplyRules}
              disabled={isPending}
            >
              {isPending
                ? "Application..."
                : "Appliquer aux transactions non taguées"}
            </Button>
            <Button size="sm" onClick={openAddRule}>
              Ajouter
            </Button>
          </div>
        </div>

        <div className="overflow-hidden border border-border bg-card">
          <table className="w-full text-left text-sm">
            <thead>
              <tr className="border-b border-border text-xs text-muted-foreground">
                <th className="px-4 py-3 font-medium">Mot-clé</th>
                <th className="px-4 py-3 font-medium">Tag</th>
                <th className="px-4 py-3 font-medium">Priorité</th>
                <th className="px-4 py-3 text-right font-medium">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-border">
              {initialRules.length === 0 ? (
                <tr>
                  <td
                    colSpan={4}
                    className="px-4 py-8 text-center text-muted-foreground"
                  >
                    Aucune règle configurée
                  </td>
                </tr>
              ) : (
                initialRules.map((rule) => (
                  <tr
                    key={rule.id}
                    className="transition-colors hover:bg-accent"
                  >
                    <td className="px-4 py-3 font-medium">
                      &ldquo;{rule.keyword}&rdquo;
                    </td>
                    <td className="px-4 py-3">
                      {rule.tag ? (
                        <div className="flex items-center gap-2">
                          <div
                            className="h-3 w-3 rounded-full"
                            style={{ backgroundColor: rule.tag.color }}
                          />
                          {rule.tag.name}
                        </div>
                      ) : (
                        <span className="italic text-muted-foreground">
                          Inconnu
                        </span>
                      )}
                    </td>
                    <td className="px-4 py-3">{rule.priority}</td>
                    <td className="px-4 py-3 text-right">
                      <div className="flex justify-end gap-1">
                        <button
                          onClick={() => openEditRule(rule)}
                          className="p-1.5 text-muted-foreground hover:bg-background hover:text-foreground"
                        >
                          <Pencil className="h-4 w-4" />
                        </button>
                        <button
                          onClick={() => setRuleDeleteId(rule.id)}
                          className="p-1.5 text-muted-foreground hover:bg-destructive/10 hover:text-destructive"
                        >
                          <Trash2 className="h-4 w-4" />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </section>

      {/* ── Dialogs ───────────────────────────────────── */}

      <TagForm
        key={tagFormOpen ? "tag-open" : "tag-closed"}
        open={tagFormOpen}
        tag={editingTag}
        loading={isPending}
        onSubmit={handleSaveTag}
        onClose={() => setTagFormOpen(false)}
      />

      <ConfirmDialog
        open={!!tagDeleteId}
        title="Supprimer le tag ?"
        description="Les transactions associées perdront ce tag. Cette action est irréversible."
        confirmLabel="Supprimer"
        variant="danger"
        loading={isPending}
        onConfirm={handleDeleteTag}
        onCancel={() => setTagDeleteId(null)}
      />

      <RuleForm
        key={ruleFormOpen ? "rule-open" : "rule-closed"}
        open={ruleFormOpen}
        rule={editingRule}
        tags={initialTags}
        loading={isPending}
        onSubmit={handleSaveRule}
        onClose={() => setRuleFormOpen(false)}
      />

      <ConfirmDialog
        open={!!ruleDeleteId}
        title="Supprimer la règle ?"
        description="Cette règle ne sera plus appliquée aux futures transactions importées."
        confirmLabel="Supprimer"
        variant="danger"
        loading={isPending}
        onConfirm={handleDeleteRule}
        onCancel={() => setRuleDeleteId(null)}
      />
    </div>
  );
}
