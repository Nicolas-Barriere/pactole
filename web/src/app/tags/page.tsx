"use client";

import { useEffect, useState, useCallback } from "react";
import { api, ApiError } from "@/lib/api";
import { useToast } from "@/components/toast";
import { TagForm, type TagFormData } from "@/components/tag-form";
import { RuleForm, type RuleFormData } from "@/components/rule-form";
import { ConfirmDialog } from "@/components/confirm-dialog";
import type { Tag, TaggingRule } from "@/types";

export default function TagsPage() {
  const toast = useToast();
  
  const [tags, setTags] = useState<Tag[]>([]);
  const [rules, setRules] = useState<TaggingRule[]>([]);
  
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const [tagFormOpen, setTagFormOpen] = useState(false);
  const [editingTag, setEditingTag] = useState<Tag | null>(null);
  const [tagDeleteId, setTagDeleteId] = useState<string | null>(null);
  
  const [ruleFormOpen, setRuleFormOpen] = useState(false);
  const [editingRule, setEditingRule] = useState<TaggingRule | null>(null);
  const [ruleDeleteId, setRuleDeleteId] = useState<string | null>(null);

  const [formLoading, setFormLoading] = useState(false);
  const [reapplyLoading, setReapplyLoading] = useState(false);

  const fetchData = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const [tgs, rls] = await Promise.all([
        api.get<Tag[]>("/tags"),
        api.get<TaggingRule[]>("/tagging-rules"),
      ]);
      setTags(tgs);
      setRules(rls);
    } catch (err) {
      setError(
        err instanceof ApiError
          ? "Impossible de charger les données"
          : "Erreur de connexion",
      );
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchData();
  }, [fetchData]);

  function openAddTag() {
    setEditingTag(null);
    setTagFormOpen(true);
  }

  function openEditTag(tag: Tag) {
    setEditingTag(tag);
    setTagFormOpen(true);
  }

  async function handleSaveTag(data: TagFormData) {
    try {
      setFormLoading(true);
      if (editingTag) {
        await api.put(`/tags/${editingTag.id}`, data);
        toast.success("Tag modifié");
      } else {
        await api.post("/tags", data);
        toast.success("Tag créé");
      }
      setTagFormOpen(false);
      fetchData();
    } catch {
      toast.error("Erreur lors de l'enregistrement du tag");
    } finally {
      setFormLoading(false);
    }
  }

  async function handleDeleteTag() {
    if (!tagDeleteId) return;
    try {
      setFormLoading(true);
      await api.delete(`/tags/${tagDeleteId}`);
      toast.success("Tag supprimé");
      setTagDeleteId(null);
      fetchData();
    } catch {
      toast.error("Erreur lors de la suppression");
    } finally {
      setFormLoading(false);
    }
  }

  function openAddRule() {
    setEditingRule(null);
    setRuleFormOpen(true);
  }

  function openEditRule(rule: TaggingRule) {
    setEditingRule(rule);
    setRuleFormOpen(true);
  }

  async function handleSaveRule(data: RuleFormData) {
    try {
      setFormLoading(true);
      if (editingRule) {
        await api.put(`/tagging-rules/${editingRule.id}`, data);
        toast.success("Règle modifiée");
      } else {
        await api.post("/tagging-rules", data);
        toast.success("Règle créée");
      }
      setRuleFormOpen(false);
      fetchData();
    } catch {
      toast.error("Erreur lors de l'enregistrement de la règle");
    } finally {
      setFormLoading(false);
    }
  }

  async function handleDeleteRule() {
    if (!ruleDeleteId) return;
    try {
      setFormLoading(true);
      await api.delete(`/tagging-rules/${ruleDeleteId}`);
      toast.success("Règle supprimée");
      setRuleDeleteId(null);
      fetchData();
    } catch {
      toast.error("Erreur lors de la suppression");
    } finally {
      setFormLoading(false);
    }
  }

  async function handleReapplyRules() {
    try {
      setReapplyLoading(true);
      const res = await api.post<{ tagged_count: number }>("/tagging-rules/apply");
      toast.success(`${res.tagged_count} transactions taguées avec succès`);
    } catch {
      toast.error("Erreur lors de l'application des règles");
    } finally {
      setReapplyLoading(false);
    }
  }

  return (
    <div className="space-y-10">
      <div>
        <h1 className="text-2xl font-bold tracking-tight">Tags & Règles</h1>
        <p className="text-sm text-muted">
          Gérez vos tags et les règles d&apos;auto-tagging
        </p>
      </div>

      {error && (
        <div className="rounded-xl border border-danger/30 bg-danger/5 p-6 text-center">
          <p className="text-sm text-danger">{error}</p>
          <button
            onClick={fetchData}
            className="mt-3 text-sm font-medium text-primary hover:text-primary-hover"
          >
            Réessayer
          </button>
        </div>
      )}

      {loading ? (
        <div className="text-center py-10 text-muted animate-pulse">Chargement...</div>
      ) : !error ? (
        <>
          {/* TAGS SECTION */}
          <section>
            <div className="mb-4 flex items-center justify-between">
              <h2 className="text-lg font-semibold tracking-tight">Tags</h2>
              <button
                onClick={openAddTag}
                className="rounded-lg bg-primary px-3 py-1.5 text-sm font-medium text-white transition-colors hover:bg-primary-hover"
              >
                Ajouter
              </button>
            </div>
            
            <div className="grid gap-3 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4">
              {tags.map((tag) => (
                <div
                  key={tag.id}
                  className="group flex items-center justify-between rounded-xl border border-border bg-card p-3 transition-colors hover:border-primary/30 hover:bg-card-hover"
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
                      className="rounded p-1.5 text-muted hover:bg-background hover:text-foreground"
                      title="Modifier"
                    >
                      <EditIcon className="h-4 w-4" />
                    </button>
                    <button
                      onClick={() => setTagDeleteId(tag.id)}
                      className="rounded p-1.5 text-muted hover:bg-danger/10 hover:text-danger"
                      title="Supprimer"
                    >
                      <TrashIcon className="h-4 w-4" />
                    </button>
                  </div>
                </div>
              ))}
              {tags.length === 0 && (
                <div className="col-span-full rounded-xl border border-dashed border-border p-6 text-center text-sm text-muted">
                  Aucun tag configuré
                </div>
              )}
            </div>
          </section>

          {/* RULES SECTION */}
          <section>
            <div className="mb-4 flex items-center justify-between">
              <h2 className="text-lg font-semibold tracking-tight">Règles d&apos;auto-tagging</h2>
              <div className="flex gap-2">
                <button
                  onClick={handleReapplyRules}
                  disabled={reapplyLoading}
                  className="rounded-lg border border-border bg-background px-3 py-1.5 text-sm font-medium text-foreground transition-colors hover:bg-card-hover disabled:opacity-50"
                >
                  {reapplyLoading ? "Application..." : "Appliquer aux transactions non taguées"}
                </button>
                <button
                  onClick={openAddRule}
                  className="rounded-lg bg-secondary px-3 py-1.5 text-sm font-medium text-foreground transition-colors hover:bg-secondary-hover"
                >
                  Ajouter
                </button>
              </div>
            </div>

            <div className="overflow-hidden rounded-xl border border-border bg-card">
              <table className="w-full text-left text-sm">
                <thead>
                  <tr className="border-b border-border bg-muted/5">
                    <th className="px-4 py-3 font-medium">Mot-clé</th>
                    <th className="px-4 py-3 font-medium">Tag</th>
                    <th className="px-4 py-3 font-medium">Priorité</th>
                    <th className="px-4 py-3 text-right font-medium">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border">
                  {rules.length === 0 ? (
                    <tr>
                      <td colSpan={4} className="px-4 py-8 text-center text-muted">
                        Aucune règle configurée
                      </td>
                    </tr>
                  ) : (
                    rules.map((rule) => (
                        <tr key={rule.id} className="transition-colors hover:bg-card-hover">
                          <td className="px-4 py-3 font-medium">&ldquo;{rule.keyword}&rdquo;</td>
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
                              <span className="text-muted italic">Inconnu</span>
                            )}
                          </td>
                          <td className="px-4 py-3">{rule.priority}</td>
                          <td className="px-4 py-3 text-right">
                            <div className="flex justify-end gap-1">
                              <button
                                onClick={() => openEditRule(rule)}
                                className="rounded p-1.5 text-muted hover:bg-background hover:text-foreground"
                              >
                                <EditIcon className="h-4 w-4" />
                              </button>
                              <button
                                onClick={() => setRuleDeleteId(rule.id)}
                                className="rounded p-1.5 text-muted hover:bg-danger/10 hover:text-danger"
                              >
                                <TrashIcon className="h-4 w-4" />
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
        </>
      ) : null}

      <TagForm
        key={tagFormOpen ? "tag-open" : "tag-closed"}
        open={tagFormOpen}
        tag={editingTag}
        loading={formLoading}
        onSubmit={handleSaveTag}
        onClose={() => setTagFormOpen(false)}
      />

      <ConfirmDialog
        open={!!tagDeleteId}
        title="Supprimer le tag ?"
        description="Les transactions associées perdront ce tag. Cette action est irréversible."
        confirmLabel="Supprimer"
        variant="danger"
        loading={formLoading}
        onConfirm={handleDeleteTag}
        onCancel={() => setTagDeleteId(null)}
      />

      <RuleForm
        key={ruleFormOpen ? "rule-open" : "rule-closed"}
        open={ruleFormOpen}
        rule={editingRule}
        tags={tags}
        loading={formLoading}
        onSubmit={handleSaveRule}
        onClose={() => setRuleFormOpen(false)}
      />

      <ConfirmDialog
        open={!!ruleDeleteId}
        title="Supprimer la règle ?"
        description="Cette règle ne sera plus appliquée aux futures transactions importées."
        confirmLabel="Supprimer"
        variant="danger"
        loading={formLoading}
        onConfirm={handleDeleteRule}
        onCancel={() => setRuleDeleteId(null)}
      />
    </div>
  );
}

function EditIcon({ className }: { className?: string }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
      <path strokeLinecap="round" strokeLinejoin="round" d="m16.862 4.487 1.687-1.688a1.875 1.875 0 1 1 2.652 2.652L6.832 19.82a4.5 4.5 0 0 1-1.897 1.13l-2.685.8.8-2.685a4.5 4.5 0 0 1 1.13-1.897L16.863 4.487Zm0 0L19.5 7.125" />
    </svg>
  );
}

function TrashIcon({ className }: { className?: string }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
      <path strokeLinecap="round" strokeLinejoin="round" d="m14.74 9-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 0 1-2.244 2.077H8.084a2.25 2.25 0 0 1-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 0 0-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 0 1 3.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 0 0-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 0 0-7.5 0" />
    </svg>
  );
}
