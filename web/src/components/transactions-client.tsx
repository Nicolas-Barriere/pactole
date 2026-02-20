"use client";

import { useState, useTransition, useCallback, useRef, useEffect } from "react";
import { useRouter, usePathname, useSearchParams } from "next/navigation";
import { toast } from "sonner";
import {
  Search,
  Plus,
  Check,
  ChevronLeft,
  ChevronRight,
  ArrowUpDown,
  ArrowUp,
  ArrowDown,
  CalendarIcon,
  X,
} from "lucide-react";
import {
  useReactTable,
  getCoreRowModel,
  flexRender,
  type ColumnDef,
  type SortingState,
  type RowSelectionState,
} from "@tanstack/react-table";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Checkbox } from "@/components/ui/checkbox";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from "@/components/ui/popover";
import { Calendar } from "@/components/ui/calendar";
import {
  TransactionForm,
  type TransactionFormData,
} from "@/components/transaction-form";
import {
  updateTransactionTags,
  bulkTagTransactions,
  createTransaction,
} from "@/app/actions/transactions";
import type { Transaction, Account, Tag, PaginatedResponse } from "@/types";

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

/* ── Props ───────────────────────────────────────────── */

interface TransactionsClientProps {
  initialData: PaginatedResponse<Transaction>;
  accounts: Account[];
  tags: Tag[];
  searchParamsObj: {
    page: number;
    search: string;
    accountFilter: string;
    tagFilter: string;
    dateFrom: string;
    dateTo: string;
    sortBy: string;
    sortOrder: string;
  };
}

/* ── Main Component ──────────────────────────────────── */

export function TransactionsClient({
  initialData,
  accounts,
  tags,
  searchParamsObj,
}: TransactionsClientProps) {
  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useSearchParams();
  const [isPending, startTransition] = useTransition();

  const {
    search,
    accountFilter,
    tagFilter,
    dateFrom,
    dateTo,
    sortBy,
    sortOrder,
  } = searchParamsObj;

  const transactions = initialData.data;
  const meta = initialData.meta;

  /* Local state */
  const [searchInput, setSearchInput] = useState(search);
  const [rowSelection, setRowSelection] = useState<RowSelectionState>({});
  const [editingTxId, setEditingTxId] = useState<string | null>(null);
  const [savedTxId, setSavedTxId] = useState<string | null>(null);
  const [addOpen, setAddOpen] = useState(false);
  const [bulkTagId, setBulkTagId] = useState("");
  const [bulkPending, startBulkTransition] = useTransition();
  const [sorting, setSorting] = useState<SortingState>([
    { id: sortBy, desc: sortOrder === "desc" },
  ]);

  /* Reset selection when data changes */
  useEffect(() => {
    setRowSelection({});
  }, [initialData]);

  /* Sync search input with URL param */
  useEffect(() => {
    setSearchInput(search);
  }, [search]);

  /* Sync sorting state with URL params */
  useEffect(() => {
    setSorting([{ id: sortBy, desc: sortOrder === "desc" }]);
  }, [sortBy, sortOrder]);

  /* ── URL updater ───────────────────────────────────── */

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

  /* ── Inline tag toggle ─────────────────────────────── */

  function handleTagToggle(txId: string, tagId: string) {
    const tx = transactions.find((t) => t.id === txId);
    if (!tx) return;

    const hasTag = tx.tags.some((t) => t.id === tagId);
    const newTagIds = hasTag
      ? tx.tags.filter((t) => t.id !== tagId).map((t) => t.id)
      : [...tx.tags.map((t) => t.id), tagId];

    setEditingTxId(null);

    startTransition(async () => {
      const result = await updateTransactionTags(txId, newTagIds);
      if (result.success) {
        setSavedTxId(txId);
        setTimeout(() => setSavedTxId(null), 1500);
        router.refresh();
      } else {
        toast.error("Erreur lors de la mise à jour");
      }
    });
  }

  /* ── Bulk tag ──────────────────────────────────────── */

  const selectedIds = new Set(Object.keys(rowSelection));

  function handleBulkTag() {
    if (selectedIds.size === 0 || !bulkTagId) return;

    startBulkTransition(async () => {
      const tagIds = bulkTagId === "untagged" ? [] : [bulkTagId];
      const result = await bulkTagTransactions(Array.from(selectedIds), tagIds);
      if (result.success) {
        toast.success(
          `${selectedIds.size} transaction${selectedIds.size > 1 ? "s" : ""} taguée${selectedIds.size > 1 ? "s" : ""}`,
        );
        setRowSelection({});
        setBulkTagId("");
        router.refresh();
      } else {
        toast.error("Erreur lors du tagging groupé");
      }
    });
  }

  /* ── Add transaction ───────────────────────────────── */

  function handleAddTransaction(data: TransactionFormData) {
    startTransition(async () => {
      const result = await createTransaction(data.account_id, {
        date: data.date,
        label: data.label,
        amount: data.amount,
        tag_ids: data.tag_ids,
      });
      if (result.success) {
        toast.success("Transaction ajoutée");
        setAddOpen(false);
        router.refresh();
      } else {
        toast.error(result.error);
      }
    });
  }

  /* ── Column definitions ────────────────────────────── */

  const SortIcon = ({ col }: { col: ReturnType<typeof table.getColumn> }) => {
    if (!col) return <ArrowUpDown className="ml-1.5 h-3.5 w-3.5 opacity-40" />;
    const sorted = col.getIsSorted();
    if (sorted === "asc") return <ArrowUp className="ml-1.5 h-3.5 w-3.5" />;
    if (sorted === "desc") return <ArrowDown className="ml-1.5 h-3.5 w-3.5" />;
    return <ArrowUpDown className="ml-1.5 h-3.5 w-3.5 opacity-40" />;
  };

  const columns: ColumnDef<Transaction>[] = [
    {
      id: "select",
      header: ({ table: t }) => (
        <Checkbox
          checked={t.getIsAllPageRowsSelected()}
          indeterminate={
            !t.getIsAllPageRowsSelected() && t.getIsSomePageRowsSelected()
          }
          onCheckedChange={(value) => t.toggleAllPageRowsSelected(value)}
          aria-label="Tout sélectionner"
        />
      ),
      cell: ({ row }) => (
        <Checkbox
          checked={row.getIsSelected()}
          onCheckedChange={(value) => row.toggleSelected(value)}
          aria-label="Sélectionner la ligne"
        />
      ),
      enableSorting: false,
      enableHiding: false,
    },
    {
      accessorKey: "date",
      header: ({ column }) => (
        <Button
          variant="ghost"
          size="sm"
          className="-ml-3 h-8"
          onClick={() => column.toggleSorting(column.getIsSorted() === "asc")}
        >
          Date
          <SortIcon col={column} />
        </Button>
      ),
      cell: ({ row }) => (
        <span className="whitespace-nowrap text-muted-foreground">
          {formatDate(row.getValue("date"))}
        </span>
      ),
    },
    {
      accessorKey: "label",
      header: ({ column }) => (
        <Button
          variant="ghost"
          size="sm"
          className="-ml-3 h-8"
          onClick={() => column.toggleSorting(column.getIsSorted() === "asc")}
        >
          Libellé
          <SortIcon col={column} />
        </Button>
      ),
      cell: ({ row }) => (
        <div className="max-w-xs truncate">
          <HighlightedText text={row.getValue("label")} highlight={search} />
        </div>
      ),
    },
    {
      id: "tags",
      header: "Tags",
      cell: ({ row }) => {
        const tx = row.original;
        return (
          <TagsCell
            transaction={tx}
            allTags={tags}
            editing={editingTxId === tx.id}
            saved={savedTxId === tx.id}
            onEdit={() => setEditingTxId(editingTxId === tx.id ? null : tx.id)}
            onToggleTag={(tagId) => handleTagToggle(tx.id, tagId)}
            onClose={() => setEditingTxId(null)}
          />
        );
      },
    },
    {
      accessorKey: "amount",
      header: ({ column }) => (
        <div className="text-right">
          <Button
            variant="ghost"
            size="sm"
            className="-mr-3 h-8"
            onClick={() => column.toggleSorting(column.getIsSorted() === "asc")}
          >
            Montant
            <SortIcon col={column} />
          </Button>
        </div>
      ),
      cell: ({ row }) => {
        const tx = row.original;
        const amt = parseFloat(tx.amount);
        return (
          <div
            className={`whitespace-nowrap text-right font-medium tabular-nums ${
              amt >= 0 ? "text-success" : "text-danger"
            }`}
          >
            {amt >= 0 ? "+" : ""}
            {formatAmount(tx.amount, tx.currency)}
          </div>
        );
      },
    },
    {
      id: "account",
      header: "Compte",
      cell: ({ row }) => (
        <span className="whitespace-nowrap text-muted-foreground">
          {row.original.account?.name ?? "—"}
        </span>
      ),
    },
  ];

  /* ── Table instance ────────────────────────────────── */

  const table = useReactTable({
    data: transactions,
    columns,
    getRowId: (row) => row.id,
    getCoreRowModel: getCoreRowModel(),
    manualSorting: true,
    enableSortingRemoval: false,
    onSortingChange: (updater) => {
      const newSorting =
        typeof updater === "function" ? updater(sorting) : updater;
      setSorting(newSorting);
      if (newSorting.length > 0) {
        const { id, desc } = newSorting[0];
        updateParams({ sort: id, order: desc ? "desc" : "asc", page: null });
      }
    },
    onRowSelectionChange: setRowSelection,
    state: { sorting, rowSelection },
  });

  /* ── Derived values ────────────────────────────────── */

  const startItem = (meta.page - 1) * meta.per_page + 1;
  const endItem = Math.min(meta.page * meta.per_page, meta.total_count);
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
          <p className="text-sm text-muted-foreground">
            Toutes vos transactions, tous comptes confondus
          </p>
        </div>
        <Button onClick={() => setAddOpen(true)}>
          <Plus className="mr-2 h-4 w-4" />
          Ajouter une transaction
        </Button>
      </div>

      {/* Filters */}
      <div className="flex flex-wrap gap-3">
        <div className="relative min-w-[200px] flex-1">
          <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
          <Input
            value={searchInput}
            onChange={(e) => setSearchInput(e.target.value)}
            placeholder="Rechercher un libellé..."
            className="pl-9 shadow-none"
          />
        </div>

        <Select
          value={accountFilter || "_all"}
          onValueChange={(v) =>
            updateParams({ account: v === "_all" ? null : v, page: null })
          }
        >
          <SelectTrigger className="w-44 shadow-none">
            <SelectValue placeholder="Tous les comptes" />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="_all">Tous les comptes</SelectItem>
            {accounts.map((a) => (
              <SelectItem key={a.id} value={a.id}>
                {a.name}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>

        <Select
          value={tagFilter || "_all"}
          onValueChange={(v) =>
            updateParams({ tag: v === "_all" ? null : v, page: null })
          }
        >
          <SelectTrigger className="w-40 shadow-none">
            <SelectValue placeholder="Tous les tags" />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="_all">Tous les tags</SelectItem>
            <SelectItem value="untagged">Non tagué</SelectItem>
            {tags.map((t) => (
              <SelectItem key={t.id} value={t.id}>
                {t.name}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>

        <DatePickerFilter
          value={dateFrom}
          placeholder="Date de début"
          onChange={(v) => updateParams({ from: v, page: null })}
        />
        <DatePickerFilter
          value={dateTo}
          placeholder="Date de fin"
          onChange={(v) => updateParams({ to: v, page: null })}
        />
      </div>

      {/* Active filters indicator */}
      {hasFilters && (
        <div className="flex items-center gap-2">
          <span className="text-xs text-muted-foreground">Filtres actifs</span>
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
            className="text-xs font-medium text-primary hover:text-primary/80"
          >
            Réinitialiser
          </button>
        </div>
      )}

      {/* Bulk action bar */}
      {selectedIds.size > 0 && (
        <div className="flex flex-col gap-3 border border-primary/30 bg-primary/5 px-4 py-3 sm:flex-row sm:items-center">
          <span className="text-sm font-medium text-primary">
            {selectedIds.size} transaction
            {selectedIds.size > 1 ? "s" : ""} sélectionnée
            {selectedIds.size > 1 ? "s" : ""}
          </span>
          <div className="flex items-center gap-2 sm:ml-auto">
            <Select
              value={bulkTagId}
              onValueChange={(value) => setBulkTagId(value ?? "")}
            >
              <SelectTrigger className="h-8 w-44 text-sm">
                <SelectValue placeholder="Choisir un tag" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="untagged">Aucun tag</SelectItem>
                {tags.map((t) => (
                  <SelectItem key={t.id} value={t.id}>
                    {t.name}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
            <Button
              size="sm"
              onClick={handleBulkTag}
              disabled={!bulkTagId || bulkPending}
            >
              {bulkPending ? "..." : "Appliquer"}
            </Button>
            <Button
              size="sm"
              variant="outline"
              onClick={() => setRowSelection({})}
            >
              Désélectionner
            </Button>
          </div>
        </div>
      )}

      {/* Table */}
      {transactions.length === 0 ? (
        <div className="border border-dashed border-border bg-card p-12 text-center text-sm text-muted-foreground">
          {hasFilters
            ? "Aucune transaction ne correspond à vos filtres."
            : "Aucune transaction pour le moment. Importez un fichier CSV pour commencer."}
        </div>
      ) : (
        <div
          className={`overflow-hidden rounded-md border border-border transition-opacity ${
            isPending ? "opacity-60" : ""
          }`}
        >
          <Table>
            <TableHeader>
              {table.getHeaderGroups().map((headerGroup) => (
                <TableRow key={headerGroup.id}>
                  {headerGroup.headers.map((header) => (
                    <TableHead key={header.id}>
                      {header.isPlaceholder
                        ? null
                        : flexRender(
                            header.column.columnDef.header,
                            header.getContext(),
                          )}
                    </TableHead>
                  ))}
                </TableRow>
              ))}
            </TableHeader>
            <TableBody>
              {table.getRowModel().rows.map((row) => (
                <TableRow
                  key={row.id}
                  data-state={row.getIsSelected() && "selected"}
                >
                  {row.getVisibleCells().map((cell) => (
                    <TableCell key={cell.id}>
                      {flexRender(
                        cell.column.columnDef.cell,
                        cell.getContext(),
                      )}
                    </TableCell>
                  ))}
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </div>
      )}

      {/* Pagination */}
      {meta.total_count > 0 && (
        <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <span className="text-sm text-muted-foreground">
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
        loading={isPending}
        onSubmit={handleAddTransaction}
        onClose={() => setAddOpen(false)}
      />
    </div>
  );
}

/* ── Date picker filter ──────────────────────────────── */

function DatePickerFilter({
  value,
  placeholder,
  onChange,
}: {
  value: string;
  placeholder: string;
  onChange: (v: string | null) => void;
}) {
  const [open, setOpen] = useState(false);

  const selected = value ? new Date(value + "T00:00:00") : undefined;

  const label = selected
    ? new Intl.DateTimeFormat("fr-FR", {
        day: "numeric",
        month: "short",
        year: "numeric",
      }).format(selected)
    : null;

  return (
    <Popover open={open} onOpenChange={setOpen}>
      <PopoverTrigger className="focus-visible:border-ring focus-visible:ring-ring/50 aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40 aria-invalid:border-destructive border-input bg-background shadow-xs hover:bg-accent hover:text-accent-foreground flex h-9 w-40 cursor-pointer items-center justify-start gap-2 rounded-none border px-3 text-sm font-normal transition-all outline-none focus-visible:ring-[3px]">
        <CalendarIcon className="h-4 w-4 shrink-0 text-muted-foreground" />
        {label ? (
          <span className="flex-1 truncate text-left">{label}</span>
        ) : (
          <span className="flex-1 text-left text-muted-foreground">
            {placeholder}
          </span>
        )}
        {value && (
          <X
            className="ml-auto h-3.5 w-3.5 shrink-0 text-muted-foreground hover:text-foreground"
            onClick={(e) => {
              e.stopPropagation();
              onChange(null);
            }}
          />
        )}
      </PopoverTrigger>
      <PopoverContent className="w-auto p-0" align="start">
        <Calendar
          mode="single"
          selected={selected}
          onSelect={(date) => {
            if (date) {
              const iso = date.toLocaleDateString("en-CA"); // YYYY-MM-DD
              onChange(iso);
            } else {
              onChange(null);
            }
            setOpen(false);
          }}
        />
      </PopoverContent>
    </Popover>
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
        className="flex items-center gap-1 px-1.5 py-0.5 text-sm transition-colors hover:bg-background"
      >
        {txTags.length > 0 ? (
          <span className="flex flex-wrap gap-1">
            {txTags.map((tag) => (
              <span
                key={tag.id}
                className="inline-flex items-center gap-1 px-2 py-0.5 text-xs font-medium"
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
          <span className="text-muted-foreground/50">—</span>
        )}
        {saved && <Check className="h-3.5 w-3.5 text-success" />}
      </button>

      {editing && (
        <div className="absolute left-0 top-full z-20 mt-1 max-h-60 w-52 overflow-y-auto border border-border bg-card py-1 shadow-xl">
          {allTags.map((tag) => {
            const isActive = txTags.some((t) => t.id === tag.id);
            return (
              <button
                key={tag.id}
                onClick={() => onToggleTag(tag.id)}
                className={`flex w-full items-center gap-2 px-3 py-1.5 text-left text-sm transition-colors hover:bg-accent ${
                  isActive ? "font-medium text-foreground" : ""
                }`}
              >
                <span
                  className="inline-block h-2 w-2 shrink-0 rounded-full"
                  style={{ backgroundColor: tag.color }}
                />
                <span className="flex-1">{tag.name}</span>
                {isActive && <Check className="h-3.5 w-3.5 text-primary" />}
              </button>
            );
          })}
          {allTags.length === 0 && (
            <p className="px-3 py-2 text-xs text-muted-foreground">
              Aucun tag disponible
            </p>
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
          <mark key={i} className="bg-primary/25 px-0.5 text-foreground">
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

  return (
    <div className="flex items-center gap-1">
      <Button
        variant="ghost"
        size="icon"
        onClick={() => onPageChange(page - 1)}
        disabled={page <= 1}
      >
        <ChevronLeft className="h-4 w-4" />
      </Button>
      {pages.map((p, i) =>
        p === "ellipsis" ? (
          <span key={`e${i}`} className="px-1 text-muted-foreground">
            …
          </span>
        ) : (
          <Button
            key={p}
            variant={p === page ? "default" : "ghost"}
            size="sm"
            onClick={() => onPageChange(p)}
          >
            {p}
          </Button>
        ),
      )}
      <Button
        variant="ghost"
        size="icon"
        onClick={() => onPageChange(page + 1)}
        disabled={page >= totalPages}
      >
        <ChevronRight className="h-4 w-4" />
      </Button>
    </div>
  );
}
