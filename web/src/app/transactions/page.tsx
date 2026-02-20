"use client";

import { Suspense, useEffect, useState, useCallback, useRef } from "react";
import { useSearchParams, useRouter, usePathname } from "next/navigation";
import { api, ApiError } from "@/lib/api";
import { useToast } from "@/components/toast";
import {
  TransactionForm,
  type TransactionFormData,
} from "@/components/transaction-form";
import type {
  Transaction,
  Account,
  Tag,
  TagRef,
  PaginatedResponse,
} from "@/types";

/* ── Constants ───────────────────────────────────────── */

const PER_PAGE = 50;

/* ── Helpers ─────────────────────────────────────────── */

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

/* ── Main content ────────────────────────────────────── */

function TransactionsContent() {
  const searchParams = useSearchParams();
  const router = useRouter();
  const pathname = usePathname();
  const toast = useToast();

  /* URL-derived state */
  const page = Number(searchParams.get("page")) || 1;
  const search = searchParams.get("search") || "";
  const accountFilter = searchParams.get("account") || "";
  const tagFilter = searchParams.get("tag") || "";
  const dateFrom = searchParams.get("from") || "";
  const dateTo = searchParams.get("to") || "";
  const sortBy = searchParams.get("sort") || "date";
  const sortOrder = searchParams.get("order") || "desc";

  /* Data state */
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [meta, setMeta] = useState({
    page: 1,
    per_page: PER_PAGE,
    total_count: 0,
    total_pages: 0,
  });
  const [accounts, setAccounts] = useState<Account[]>([]);
  const [tags, setTags] = useState<Tag[]>([]);
  const [loading, setLoading] = useState(true);

  /* Search input (debounced) */
  const [searchInput, setSearchInput] = useState(search);

  /* Selection */
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());

  /* Inline tag editing */
  const [editingTxId, setEditingTxId] = useState<string | null>(null);
  const [savedTxId, setSavedTxId] = useState<string | null>(null);

  /* Add transaction modal */
  const [addOpen, setAddOpen] = useState(false);
  const [addLoading, setAddLoading] = useState(false);

  /* Bulk tag */
  const [bulkTagId, setBulkTagId] = useState("");
  const [bulkLoading, setBulkLoading] = useState(false);

  /* ── URL param updater ─────────────────────────────── */

  const updateParams = useCallback(
    (updates: Record<string, string | null>) => {
      const params = new URLSearchParams(searchParams.toString());
      for (const [key, value] of Object.entries(updates)) {
        if (value === null || value === "") {
          params.delete(key);
        } else {
          params.set(key, value);
        }
      }
      const qs = params.toString();
      router.push(qs ? `${pathname}?${qs}` : pathname);
    },
    [searchParams, router, pathname],
  );

  /* ── Debounced search ──────────────────────────────── */

  useEffect(() => {
    const timer = setTimeout(() => {
      if (searchInput !== search) {
        updateParams({ search: searchInput || null, page: null });
      }
    }, 300);
    return () => clearTimeout(timer);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [searchInput]);

  useEffect(() => {
    setSearchInput(search);
  }, [search]);

  /* ── Data fetching ─────────────────────────────────── */

  const fetchTransactions = useCallback(async () => {
    try {
      setLoading(true);
      const p = new URLSearchParams();
      p.set("page", String(page));
      p.set("per_page", String(PER_PAGE));
      if (search) p.set("search", search);
      if (accountFilter) p.set("account_id", accountFilter);
      if (tagFilter) p.set("tag_id", tagFilter);
      if (dateFrom) p.set("date_from", dateFrom);
      if (dateTo) p.set("date_to", dateTo);
      p.set("sort_by", sortBy);
      p.set("sort_order", sortOrder);

      const result = await api.get<PaginatedResponse<Transaction>>(
        `/transactions?${p.toString()}`,
      );
      setTransactions(result.data);
      setMeta(result.meta);
    } catch {
      toast.error("Impossible de charger les transactions");
    } finally {
      setLoading(false);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [
    page,
    search,
    accountFilter,
    tagFilter,
    dateFrom,
    dateTo,
    sortBy,
    sortOrder,
  ]);

  useEffect(() => {
    api
      .get<Account[]>("/accounts")
      .then(setAccounts)
      .catch(() => {});
    api
      .get<Tag[]>("/tags")
      .then(setTags)
      .catch(() => {});
  }, []);

  useEffect(() => {
    fetchTransactions();
    setSelectedIds(new Set());
  }, [fetchTransactions]);

  /* ── Handlers ──────────────────────────────────────── */

  function handleSort(field: string) {
    if (sortBy === field) {
      updateParams({ order: sortOrder === "desc" ? "asc" : "desc" });
    } else {
      updateParams({ sort: field, order: "desc", page: null });
    }
  }

  function toggleSelect(id: string) {
    setSelectedIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }

  function toggleSelectAll() {
    if (selectedIds.size === transactions.length) {
      setSelectedIds(new Set());
    } else {
      setSelectedIds(new Set(transactions.map((t) => t.id)));
    }
  }

  async function handleTagToggle(txId: string, tagId: string) {
    const tx = transactions.find((t) => t.id === txId);
    if (!tx) return;

    const oldTags = tx.tags;
    const hasTag = oldTags.some((t) => t.id === tagId);
    const newTagIds = hasTag
      ? oldTags.filter((t) => t.id !== tagId).map((t) => t.id)
      : [...oldTags.map((t) => t.id), tagId];

    const newTagRefs: TagRef[] = newTagIds
      .map((id) => tags.find((t) => t.id === id))
      .filter((t): t is Tag => !!t)
      .map((t) => ({ id: t.id, name: t.name, color: t.color }));

    setTransactions((prev) =>
      prev.map((t) =>
        t.id === txId ? { ...t, tags: newTagRefs } : t,
      ),
    );
    setEditingTxId(null);

    try {
      await api.put(`/transactions/${txId}`, { tag_ids: newTagIds });
      setSavedTxId(txId);
      setTimeout(() => setSavedTxId(null), 1500);
    } catch {
      setTransactions((prev) =>
        prev.map((t) =>
          t.id === txId ? { ...t, tags: oldTags } : t,
        ),
      );
      toast.error("Erreur lors de la mise à jour");
    }
  }

  async function handleBulkTag() {
    if (selectedIds.size === 0 || !bulkTagId) return;

    try {
      setBulkLoading(true);
      const tagIds = bulkTagId === "untagged" ? [] : [bulkTagId];
      await api.patch("/transactions/bulk-tag", {
        transaction_ids: Array.from(selectedIds),
        tag_ids: tagIds,
      });
      toast.success(
        `${selectedIds.size} transaction${selectedIds.size > 1 ? "s" : ""} taguée${selectedIds.size > 1 ? "s" : ""}`,
      );
      setSelectedIds(new Set());
      setBulkTagId("");
      fetchTransactions();
    } catch {
      toast.error("Erreur lors du tagging groupé");
    } finally {
      setBulkLoading(false);
    }
  }

  async function handleAddTransaction(data: TransactionFormData) {
    try {
      setAddLoading(true);
      await api.post(`/accounts/${data.account_id}/transactions`, {
        date: data.date,
        label: data.label,
        amount: data.amount,
        tag_ids: data.tag_ids,
      });
      toast.success("Transaction ajoutée");
      setAddOpen(false);
      fetchTransactions();
    } catch (err) {
      if (err instanceof ApiError && err.body) {
        const body = err.body as { errors?: Record<string, string[]> };
        const messages = body.errors
          ? Object.values(body.errors).flat().join(", ")
          : "Erreur lors de l'ajout";
        toast.error(messages);
      } else {
        toast.error("Erreur de connexion");
      }
    } finally {
      setAddLoading(false);
    }
  }

  /* ── Derived values ────────────────────────────────── */

  const startItem = (meta.page - 1) * meta.per_page + 1;
  const endItem = Math.min(meta.page * meta.per_page, meta.total_count);
  const allSelected =
    transactions.length > 0 && selectedIds.size === transactions.length;
  const hasFilters = !!(
    accountFilter ||
    tagFilter ||
    dateFrom ||
    dateTo ||
    search
  );

  /* ── Render ────────────────────────────────────────── */

  return (
    <div className="space-y-4">
      {/* Header */}
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-2xl font-bold tracking-tight">Transactions</h1>
          <p className="text-sm text-muted">
            Toutes vos transactions, tous comptes confondus
          </p>
        </div>
        <button
          onClick={() => setAddOpen(true)}
          className="flex items-center gap-2 rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white transition-colors hover:bg-primary-hover"
        >
          <PlusIcon className="h-4 w-4" />
          Ajouter une transaction
        </button>
      </div>

      {/* Filters */}
      <div className="flex flex-wrap gap-3">
        <div className="relative min-w-[200px] flex-1">
          <SearchIcon className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted" />
          <input
            type="text"
            value={searchInput}
            onChange={(e) => setSearchInput(e.target.value)}
            placeholder="Rechercher un libellé..."
            className="w-full rounded-lg border border-border bg-background py-2 pl-9 pr-3 text-sm outline-none transition-colors focus:border-primary"
          />
        </div>

        <select
          value={accountFilter}
          onChange={(e) =>
            updateParams({ account: e.target.value || null, page: null })
          }
          className="rounded-lg border border-border bg-background px-3 py-2 text-sm outline-none transition-colors focus:border-primary"
        >
          <option value="">Tous les comptes</option>
          {accounts.map((a) => (
            <option key={a.id} value={a.id}>
              {a.name}
            </option>
          ))}
        </select>

        <select
          value={tagFilter}
          onChange={(e) =>
            updateParams({ tag: e.target.value || null, page: null })
          }
          className="rounded-lg border border-border bg-background px-3 py-2 text-sm outline-none transition-colors focus:border-primary"
        >
          <option value="">Tous les tags</option>
          <option value="untagged">Non tagué</option>
          {tags.map((t) => (
            <option key={t.id} value={t.id}>
              {t.name}
            </option>
          ))}
        </select>

        <input
          type="date"
          value={dateFrom}
          onChange={(e) =>
            updateParams({ from: e.target.value || null, page: null })
          }
          className="rounded-lg border border-border bg-background px-3 py-2 text-sm outline-none transition-colors focus:border-primary"
        />
        <input
          type="date"
          value={dateTo}
          onChange={(e) =>
            updateParams({ to: e.target.value || null, page: null })
          }
          className="rounded-lg border border-border bg-background px-3 py-2 text-sm outline-none transition-colors focus:border-primary"
        />
      </div>

      {/* Active filters indicator */}
      {hasFilters && (
        <div className="flex items-center gap-2">
          <span className="text-xs text-muted">Filtres actifs</span>
          <button
            onClick={() =>
              updateParams({
                account: null,
                tag: null,
                from: null,
                to: null,
                search: null,
                page: null,
              })
            }
            className="text-xs font-medium text-primary hover:text-primary-hover"
          >
            Réinitialiser
          </button>
        </div>
      )}

      {/* Bulk action bar */}
      {selectedIds.size > 0 && (
        <div className="flex flex-col gap-3 rounded-lg border border-primary/30 bg-primary/5 px-4 py-3 sm:flex-row sm:items-center">
          <span className="text-sm font-medium text-primary">
            {selectedIds.size} transaction
            {selectedIds.size > 1 ? "s" : ""} sélectionnée
            {selectedIds.size > 1 ? "s" : ""}
          </span>
          <div className="flex items-center gap-2 sm:ml-auto">
            <select
              value={bulkTagId}
              onChange={(e) => setBulkTagId(e.target.value)}
              className="rounded-lg border border-border bg-background px-3 py-1.5 text-sm outline-none"
            >
              <option value="">Choisir un tag</option>
              <option value="untagged">Aucun tag</option>
              {tags.map((t) => (
                <option key={t.id} value={t.id}>
                  {t.name}
                </option>
              ))}
            </select>
            <button
              onClick={handleBulkTag}
              disabled={!bulkTagId || bulkLoading}
              className="rounded-lg bg-primary px-3 py-1.5 text-sm font-medium text-white transition-colors hover:bg-primary-hover disabled:opacity-50"
            >
              {bulkLoading ? "..." : "Appliquer"}
            </button>
            <button
              onClick={() => setSelectedIds(new Set())}
              className="rounded-lg border border-border px-3 py-1.5 text-sm text-muted transition-colors hover:text-foreground"
            >
              Désélectionner
            </button>
          </div>
        </div>
      )}

      {/* Table */}
      {loading ? (
        <TableSkeleton />
      ) : transactions.length === 0 ? (
        <div className="rounded-xl border border-dashed border-border bg-card p-12 text-center text-sm text-muted">
          {hasFilters
            ? "Aucune transaction ne correspond à vos filtres."
            : "Aucune transaction pour le moment. Importez un fichier CSV pour commencer."}
        </div>
      ) : (
        <div className="overflow-hidden rounded-xl border border-border bg-card">
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-border text-left text-xs text-muted">
                  <th className="w-10 px-4 py-3">
                    <input
                      type="checkbox"
                      checked={allSelected}
                      onChange={toggleSelectAll}
                      className="accent-primary"
                    />
                  </th>
                  <SortHeader
                    field="date"
                    label="Date"
                    active={sortBy}
                    order={sortOrder}
                    onSort={handleSort}
                  />
                  <SortHeader
                    field="label"
                    label="Libellé"
                    active={sortBy}
                    order={sortOrder}
                    onSort={handleSort}
                  />
                  <th className="px-4 py-3 font-medium">Tags</th>
                  <SortHeader
                    field="amount"
                    label="Montant"
                    active={sortBy}
                    order={sortOrder}
                    onSort={handleSort}
                    align="right"
                  />
                  <th className="px-4 py-3 font-medium">Compte</th>
                </tr>
              </thead>
              <tbody>
                {transactions.map((tx) => {
                  const amt = parseFloat(tx.amount);
                  return (
                    <tr
                      key={tx.id}
                      className="border-b border-border last:border-0 hover:bg-card-hover"
                    >
                      <td className="px-4 py-3">
                        <input
                          type="checkbox"
                          checked={selectedIds.has(tx.id)}
                          onChange={() => toggleSelect(tx.id)}
                          className="accent-primary"
                        />
                      </td>
                      <td className="whitespace-nowrap px-4 py-3 text-muted">
                        {formatDate(tx.date)}
                      </td>
                      <td className="max-w-xs truncate px-4 py-3">
                        <HighlightedText text={tx.label} highlight={search} />
                      </td>
                      <td className="px-4 py-3">
                        <TagsCell
                          transaction={tx}
                          allTags={tags}
                          editing={editingTxId === tx.id}
                          saved={savedTxId === tx.id}
                          onEdit={() =>
                            setEditingTxId(
                              editingTxId === tx.id ? null : tx.id,
                            )
                          }
                          onToggleTag={(tagId) =>
                            handleTagToggle(tx.id, tagId)
                          }
                          onClose={() => setEditingTxId(null)}
                        />
                      </td>
                      <td
                        className={`whitespace-nowrap px-4 py-3 text-right font-medium tabular-nums ${
                          amt >= 0 ? "text-success" : "text-danger"
                        }`}
                      >
                        {amt >= 0 ? "+" : ""}
                        {formatAmount(tx.amount, tx.currency)}
                      </td>
                      <td className="whitespace-nowrap px-4 py-3 text-muted">
                        {tx.account?.name ?? "—"}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Pagination */}
      {meta.total_count > 0 && (
        <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <span className="text-sm text-muted">
            Affichage {startItem}–{endItem} sur {meta.total_count} transaction
            {meta.total_count > 1 ? "s" : ""}
          </span>
          {meta.total_pages > 1 && (
            <PaginationNav
              page={meta.page}
              totalPages={meta.total_pages}
              onPageChange={(p) =>
                updateParams({ page: p === 1 ? null : String(p) })
              }
            />
          )}
        </div>
      )}

      {/* Add transaction modal */}
      <TransactionForm
        key={addOpen ? "add" : "closed"}
        open={addOpen}
        accounts={accounts}
        tags={tags}
        defaultAccountId={accountFilter}
        loading={addLoading}
        onSubmit={handleAddTransaction}
        onClose={() => setAddOpen(false)}
      />
    </div>
  );
}

/* ── Sortable column header ──────────────────────────── */

function SortHeader({
  field,
  label,
  active,
  order,
  onSort,
  align,
}: {
  field: string;
  label: string;
  active: string;
  order: string;
  onSort: (f: string) => void;
  align?: "right";
}) {
  const isActive = active === field;
  return (
    <th
      className={`cursor-pointer select-none px-4 py-3 font-medium transition-colors hover:text-foreground ${
        align === "right" ? "text-right" : ""
      } ${isActive ? "text-foreground" : ""}`}
      onClick={() => onSort(field)}
    >
      <span className="inline-flex items-center gap-1">
        {label}
        {isActive ? (
          order === "asc" ? (
            <ChevronUpIcon className="h-3 w-3" />
          ) : (
            <ChevronDownIcon className="h-3 w-3" />
          )
        ) : (
          <ChevronUpDownIcon className="h-3 w-3 opacity-30" />
        )}
      </span>
    </th>
  );
}

/* ── Inline tags cell ────────────────────────────────── */

function TagsCell({
  transaction,
  allTags,
  editing,
  saved,
  onEdit,
  onToggleTag,
  onClose,
}: {
  transaction: Transaction;
  allTags: Tag[];
  editing: boolean;
  saved: boolean;
  onEdit: () => void;
  onToggleTag: (tagId: string) => void;
  onClose: () => void;
}) {
  const dropdownRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!editing) return;
    function handleClick(e: MouseEvent) {
      if (
        dropdownRef.current &&
        !dropdownRef.current.contains(e.target as Node)
      ) {
        onClose();
      }
    }
    document.addEventListener("mousedown", handleClick);
    return () => document.removeEventListener("mousedown", handleClick);
  }, [editing, onClose]);

  const txTags = transaction.tags;

  return (
    <div className="relative" ref={dropdownRef}>
      <button
        onClick={onEdit}
        className="flex items-center gap-1 rounded-md px-1.5 py-0.5 text-sm transition-colors hover:bg-background"
      >
        {txTags.length > 0 ? (
          <span className="flex flex-wrap gap-1">
            {txTags.map((tag) => (
              <span
                key={tag.id}
                className="inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-xs font-medium"
                style={{
                  backgroundColor: tag.color + "20",
                  color: tag.color,
                }}
              >
                <span
                  className="inline-block h-1.5 w-1.5 rounded-full"
                  style={{ backgroundColor: tag.color }}
                />
                {tag.name}
              </span>
            ))}
          </span>
        ) : (
          <span className="text-muted/50">—</span>
        )}
        {saved && <CheckAnimIcon className="h-3.5 w-3.5 text-success" />}
      </button>

      {editing && (
        <div className="absolute left-0 top-full z-20 mt-1 max-h-60 w-52 overflow-y-auto rounded-lg border border-border bg-card py-1 shadow-xl">
          {allTags.map((tag) => {
            const isActive = txTags.some((t) => t.id === tag.id);
            return (
              <button
                key={tag.id}
                onClick={() => onToggleTag(tag.id)}
                className={`flex w-full items-center gap-2 px-3 py-1.5 text-left text-sm transition-colors hover:bg-card-hover ${
                  isActive ? "font-medium text-foreground" : ""
                }`}
              >
                <span
                  className="inline-block h-2 w-2 shrink-0 rounded-full"
                  style={{ backgroundColor: tag.color }}
                />
                <span className="flex-1">{tag.name}</span>
                {isActive && (
                  <CheckAnimIcon className="h-3.5 w-3.5 text-primary" />
                )}
              </button>
            );
          })}
          {allTags.length === 0 && (
            <p className="px-3 py-2 text-xs text-muted">Aucun tag disponible</p>
          )}
        </div>
      )}
    </div>
  );
}

/* ── Search highlight ────────────────────────────────── */

function HighlightedText({
  text,
  highlight,
}: {
  text: string;
  highlight: string;
}) {
  if (!highlight.trim()) return <>{text}</>;

  const regex = new RegExp(
    `(${highlight.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")})`,
    "gi",
  );
  const parts = text.split(regex);

  return (
    <>
      {parts.map((part, i) =>
        regex.test(part) ? (
          <mark
            key={i}
            className="rounded-sm bg-primary/25 px-0.5 text-foreground"
          >
            {part}
          </mark>
        ) : (
          part
        ),
      )}
    </>
  );
}

/* ── Pagination ──────────────────────────────────────── */

function PaginationNav({
  page,
  totalPages,
  onPageChange,
}: {
  page: number;
  totalPages: number;
  onPageChange: (p: number) => void;
}) {
  const pages: (number | "ellipsis")[] = [];
  const delta = 2;

  for (let i = 1; i <= totalPages; i++) {
    if (
      i === 1 ||
      i === totalPages ||
      (i >= page - delta && i <= page + delta)
    ) {
      pages.push(i);
    } else if (pages[pages.length - 1] !== "ellipsis") {
      pages.push("ellipsis");
    }
  }

  const btnBase =
    "rounded-lg px-3 py-1.5 text-sm font-medium transition-colors";

  return (
    <div className="flex items-center gap-1">
      <button
        onClick={() => onPageChange(page - 1)}
        disabled={page <= 1}
        className={`${btnBase} text-muted hover:text-foreground disabled:opacity-30 disabled:hover:text-muted`}
      >
        <ChevronLeftIcon className="h-4 w-4" />
      </button>
      {pages.map((p, i) =>
        p === "ellipsis" ? (
          <span key={`e${i}`} className="px-1 text-muted">
            …
          </span>
        ) : (
          <button
            key={p}
            onClick={() => onPageChange(p)}
            className={`${btnBase} ${
              p === page
                ? "bg-primary text-white"
                : "text-muted hover:bg-card-hover hover:text-foreground"
            }`}
          >
            {p}
          </button>
        ),
      )}
      <button
        onClick={() => onPageChange(page + 1)}
        disabled={page >= totalPages}
        className={`${btnBase} text-muted hover:text-foreground disabled:opacity-30 disabled:hover:text-muted`}
      >
        <ChevronRightIcon className="h-4 w-4" />
      </button>
    </div>
  );
}

/* ── Page wrapper (Suspense) ─────────────────────────── */

export default function TransactionsPage() {
  return (
    <Suspense fallback={<PageSkeleton />}>
      <TransactionsContent />
    </Suspense>
  );
}

/* ── Skeletons ───────────────────────────────────────── */

function TableSkeleton() {
  return (
    <div className="overflow-hidden rounded-xl border border-border bg-card">
      {Array.from({ length: 8 }).map((_, i) => (
        <div
          key={i}
          className="flex items-center gap-4 border-b border-border px-4 py-4 last:border-0"
        >
          <div className="h-4 w-4 animate-skeleton rounded bg-muted/20" />
          <div className="h-3 w-20 animate-skeleton rounded bg-muted/20" />
          <div className="h-3 w-44 animate-skeleton rounded bg-muted/20" />
          <div className="h-3 w-20 animate-skeleton rounded bg-muted/20" />
          <div className="ml-auto h-3 w-20 animate-skeleton rounded bg-muted/20" />
          <div className="h-3 w-24 animate-skeleton rounded bg-muted/20" />
        </div>
      ))}
    </div>
  );
}

function PageSkeleton() {
  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <div className="space-y-2">
          <div className="h-7 w-40 animate-skeleton rounded bg-muted/20" />
          <div className="h-4 w-72 animate-skeleton rounded bg-muted/20" />
        </div>
        <div className="h-9 w-52 animate-skeleton rounded-lg bg-muted/20" />
      </div>
      <div className="flex gap-3">
        <div className="h-9 flex-1 animate-skeleton rounded-lg bg-muted/20" />
        <div className="h-9 w-40 animate-skeleton rounded-lg bg-muted/20" />
        <div className="h-9 w-44 animate-skeleton rounded-lg bg-muted/20" />
        <div className="h-9 w-36 animate-skeleton rounded-lg bg-muted/20" />
        <div className="h-9 w-36 animate-skeleton rounded-lg bg-muted/20" />
      </div>
      <TableSkeleton />
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

function SearchIcon({ className }: { className?: string }) {
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
        d="m21 21-5.197-5.197m0 0A7.5 7.5 0 1 0 5.196 5.196a7.5 7.5 0 0 0 10.607 10.607Z"
      />
    </svg>
  );
}

function ChevronUpIcon({ className }: { className?: string }) {
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
        d="m4.5 15.75 7.5-7.5 7.5 7.5"
      />
    </svg>
  );
}

function ChevronDownIcon({ className }: { className?: string }) {
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
        d="m19.5 8.25-7.5 7.5-7.5-7.5"
      />
    </svg>
  );
}

function ChevronUpDownIcon({ className }: { className?: string }) {
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
        d="m8.25 15 3.75 3.75 3.75-3.75m-7.5-6L12 5.25l3.75 3.75"
      />
    </svg>
  );
}

function ChevronLeftIcon({ className }: { className?: string }) {
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
        d="M15.75 19.5 8.25 12l7.5-7.5"
      />
    </svg>
  );
}

function ChevronRightIcon({ className }: { className?: string }) {
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
        d="m8.25 4.5 7.5 7.5-7.5 7.5"
      />
    </svg>
  );
}

function CheckAnimIcon({ className }: { className?: string }) {
  return (
    <svg
      className={`${className} animate-check-in`}
      fill="none"
      viewBox="0 0 24 24"
      stroke="currentColor"
      strokeWidth={2}
    >
      <path
        strokeLinecap="round"
        strokeLinejoin="round"
        d="m4.5 12.75 6 6 9-13.5"
      />
    </svg>
  );
}
