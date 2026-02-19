"use client";

import { useEffect, useState, useCallback, useRef, useMemo, type DragEvent } from "react";
import { useSearchParams } from "next/navigation";
import Link from "next/link";
import { api, ApiError } from "@/lib/api";
import { useToast } from "@/components/toast";
import { BANK_LABELS } from "@/components/account-form";
import type { Account, Import, ImportRowDetail, ImportRowStatus } from "@/types";

/* ── Helpers ─────────────────────────────────────────── */

function formatFileSize(bytes: number): string {
  if (bytes < 1024) return `${bytes} o`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} Ko`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} Mo`;
}

function formatDate(iso: string): string {
  return new Intl.DateTimeFormat("fr-FR", {
    day: "numeric",
    month: "short",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  }).format(new Date(iso));
}

/* ── Types ───────────────────────────────────────────── */

type Step = "account" | "upload" | "results";

/* ── Page Component ──────────────────────────────────── */

export default function ImportPage() {
  const searchParams = useSearchParams();
  const toast = useToast();

  const preselectedAccountId = searchParams.get("account");

  const [step, setStep] = useState<Step>("account");
  const [accounts, setAccounts] = useState<Account[]>([]);
  const [accountsLoading, setAccountsLoading] = useState(true);
  const [selectedAccountId, setSelectedAccountId] = useState<string>("");

  const [file, setFile] = useState<File | null>(null);
  const [uploading, setUploading] = useState(false);
  const [dragOver, setDragOver] = useState(false);

  const [importResult, setImportResult] = useState<Import | null>(null);
  const [importError, setImportError] = useState<string | null>(null);

  const fileInputRef = useRef<HTMLInputElement>(null);

  const fetchAccounts = useCallback(async () => {
    try {
      setAccountsLoading(true);
      const data = await api.get<Account[]>("/accounts");
      setAccounts(data);

      if (preselectedAccountId) {
        const exists = data.some((a) => a.id === preselectedAccountId);
        if (exists) {
          setSelectedAccountId(preselectedAccountId);
          setStep("upload");
        }
      }
    } catch {
      toast.error("Impossible de charger les comptes");
    } finally {
      setAccountsLoading(false);
    }
  }, [preselectedAccountId, toast]);

  useEffect(() => {
    fetchAccounts();
  }, [fetchAccounts]);

  const selectedAccount = accounts.find((a) => a.id === selectedAccountId);

  /* ── File handling ───────────────────────────── */

  function handleFileSelect(selectedFile: File | undefined) {
    if (!selectedFile) return;

    if (!selectedFile.name.toLowerCase().endsWith(".csv")) {
      toast.error("Seuls les fichiers .csv sont acceptés");
      return;
    }

    if (selectedFile.size === 0) {
      toast.error("Le fichier est vide");
      return;
    }

    setFile(selectedFile);
    setImportError(null);
  }

  function handleDragOver(e: DragEvent) {
    e.preventDefault();
    setDragOver(true);
  }

  function handleDragLeave(e: DragEvent) {
    e.preventDefault();
    setDragOver(false);
  }

  function handleDrop(e: DragEvent) {
    e.preventDefault();
    setDragOver(false);
    const droppedFile = e.dataTransfer.files[0];
    handleFileSelect(droppedFile);
  }

  /* ── Upload ──────────────────────────────────── */

  async function handleUpload() {
    if (!file || !selectedAccountId) return;

    try {
      setUploading(true);
      setImportError(null);

      const formData = new FormData();
      formData.append("file", file);

      const result = await api.upload<Import>(
        `/accounts/${selectedAccountId}/imports`,
        formData,
      );

      setImportResult(result);
      setStep("results");
      toast.success("Import terminé avec succès");
    } catch (err) {
      if (err instanceof ApiError) {
        const body = err.body as Import | { errors?: { detail?: string } } | null;

        if (body && "status" in body && body.status === "failed") {
          setImportResult(body as Import);
          setStep("results");
          return;
        }

        const errorBody = body as { errors?: { detail?: string } } | null;
        const message =
          errorBody?.errors?.detail ?? "Erreur lors de l'import";
        setImportError(message);
      } else {
        setImportError("Erreur de connexion. Veuillez réessayer.");
      }
    } finally {
      setUploading(false);
    }
  }

  /* ── Reset ───────────────────────────────────── */

  function handleReset() {
    setFile(null);
    setImportResult(null);
    setImportError(null);
    setStep("upload");
  }

  function handleFullReset() {
    setFile(null);
    setImportResult(null);
    setImportError(null);
    setSelectedAccountId("");
    setStep("account");
  }

  /* ── Step navigation ─────────────────────────── */

  function handleAccountContinue() {
    if (selectedAccountId) setStep("upload");
  }

  /* ── Render ──────────────────────────────────── */

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold tracking-tight">Importer</h1>
        <p className="text-sm text-muted">
          Importez vos relevés bancaires au format CSV
        </p>
      </div>

      {/* ── Stepper ──────────────────────────────── */}
      <StepIndicator current={step} />

      {/* ── Step 1: Account ──────────────────────── */}
      {step === "account" && (
        <AccountStep
          accounts={accounts}
          loading={accountsLoading}
          selectedAccountId={selectedAccountId}
          onSelect={setSelectedAccountId}
          onContinue={handleAccountContinue}
        />
      )}

      {/* ── Step 2: Upload ───────────────────────── */}
      {step === "upload" && selectedAccount && (
        <UploadStep
          account={selectedAccount}
          file={file}
          dragOver={dragOver}
          uploading={uploading}
          importError={importError}
          fileInputRef={fileInputRef}
          onFileSelect={handleFileSelect}
          onDragOver={handleDragOver}
          onDragLeave={handleDragLeave}
          onDrop={handleDrop}
          onUpload={handleUpload}
          onRemoveFile={() => { setFile(null); setImportError(null); }}
          onBack={() => setStep("account")}
        />
      )}

      {/* ── Step 3: Results ──────────────────────── */}
      {step === "results" && importResult && (
        <ResultsStep
          result={importResult}
          accountId={selectedAccountId}
          onImportAnother={handleReset}
          onNewAccount={handleFullReset}
        />
      )}
    </div>
  );
}

/* ── Step Indicator ──────────────────────────────────── */

const STEPS: { key: Step; label: string }[] = [
  { key: "account", label: "Compte" },
  { key: "upload", label: "Fichier" },
  { key: "results", label: "Résultat" },
];

function StepIndicator({ current }: { current: Step }) {
  const currentIndex = STEPS.findIndex((s) => s.key === current);

  return (
    <div className="flex items-center gap-2">
      {STEPS.map((s, i) => {
        const isActive = i === currentIndex;
        const isDone = i < currentIndex;

        return (
          <div key={s.key} className="flex items-center gap-2">
            {i > 0 && (
              <div
                className={`h-px w-8 transition-colors ${
                  isDone ? "bg-primary" : "bg-border"
                }`}
              />
            )}
            <div className="flex items-center gap-2">
              <span
                className={`flex h-7 w-7 items-center justify-center rounded-full text-xs font-medium transition-colors ${
                  isActive
                    ? "bg-primary text-white"
                    : isDone
                      ? "bg-primary/15 text-primary"
                      : "bg-muted/10 text-muted"
                }`}
              >
                {isDone ? <CheckIcon className="h-3.5 w-3.5" /> : i + 1}
              </span>
              <span
                className={`text-sm font-medium ${
                  isActive
                    ? "text-foreground"
                    : isDone
                      ? "text-primary"
                      : "text-muted"
                }`}
              >
                {s.label}
              </span>
            </div>
          </div>
        );
      })}
    </div>
  );
}

/* ── Step 1: Account Selection ───────────────────────── */

function AccountStep({
  accounts,
  loading,
  selectedAccountId,
  onSelect,
  onContinue,
}: {
  accounts: Account[];
  loading: boolean;
  selectedAccountId: string;
  onSelect: (id: string) => void;
  onContinue: () => void;
}) {
  if (loading) {
    return (
      <div className="rounded-xl border border-border bg-card p-6">
        <div className="space-y-4">
          <div className="h-5 w-48 animate-skeleton rounded bg-muted/20" />
          <div className="h-10 w-full animate-skeleton rounded-lg bg-muted/20" />
        </div>
      </div>
    );
  }

  if (accounts.length === 0) {
    return (
      <div className="rounded-xl border border-dashed border-border bg-card p-12 text-center">
        <BankIcon className="mx-auto mb-3 h-10 w-10 text-muted/50" />
        <p className="text-sm text-muted">
          Vous devez d&#39;abord créer un compte bancaire.
        </p>
        <Link
          href="/accounts"
          className="mt-3 inline-block text-sm font-medium text-primary hover:text-primary-hover"
        >
          Créer un compte
        </Link>
      </div>
    );
  }

  return (
    <div className="rounded-xl border border-border bg-card p-6">
      <label
        htmlFor="account-select"
        className="mb-2 block text-sm font-medium text-foreground"
      >
        Dans quel compte importer ?
      </label>
      <select
        id="account-select"
        value={selectedAccountId}
        onChange={(e) => onSelect(e.target.value)}
        className="w-full rounded-lg border border-border bg-background px-3 py-2.5 text-sm text-foreground transition-colors focus:border-primary focus:outline-none focus:ring-1 focus:ring-primary"
      >
        <option value="">Sélectionnez un compte…</option>
        {accounts.map((a) => (
          <option key={a.id} value={a.id}>
            {a.name} — {BANK_LABELS[a.bank] ?? a.bank} ({a.currency})
          </option>
        ))}
      </select>

      <div className="mt-4 flex items-center justify-between">
        <Link
          href="/accounts"
          className="text-sm text-muted hover:text-foreground"
        >
          Gérer les comptes
        </Link>
        <button
          onClick={onContinue}
          disabled={!selectedAccountId}
          className="rounded-lg bg-primary px-5 py-2 text-sm font-medium text-white transition-colors hover:bg-primary-hover disabled:cursor-not-allowed disabled:opacity-50"
        >
          Continuer
        </button>
      </div>
    </div>
  );
}

/* ── Step 2: Upload ──────────────────────────────────── */

function UploadStep({
  account,
  file,
  dragOver,
  uploading,
  importError,
  fileInputRef,
  onFileSelect,
  onDragOver,
  onDragLeave,
  onDrop,
  onUpload,
  onRemoveFile,
  onBack,
}: {
  account: Account;
  file: File | null;
  dragOver: boolean;
  uploading: boolean;
  importError: string | null;
  fileInputRef: React.RefObject<HTMLInputElement | null>;
  onFileSelect: (file: File | undefined) => void;
  onDragOver: (e: DragEvent) => void;
  onDragLeave: (e: DragEvent) => void;
  onDrop: (e: DragEvent) => void;
  onUpload: () => void;
  onRemoveFile: () => void;
  onBack: () => void;
}) {
  return (
    <div className="space-y-4">
      {/* Account reminder */}
      <div className="flex items-center justify-between rounded-xl border border-border bg-card px-4 py-3">
        <div className="flex items-center gap-3">
          <BankIcon className="h-5 w-5 text-muted" />
          <div>
            <p className="text-sm font-medium">{account.name}</p>
            <p className="text-xs text-muted">
              {BANK_LABELS[account.bank] ?? account.bank} · {account.currency}
            </p>
          </div>
        </div>
        <button
          onClick={onBack}
          className="text-sm text-muted hover:text-foreground"
        >
          Changer
        </button>
      </div>

      {/* Drop zone */}
      <div
        onDragOver={onDragOver}
        onDragLeave={onDragLeave}
        onDrop={onDrop}
        onClick={() => !file && fileInputRef.current?.click()}
        className={`relative rounded-xl border-2 border-dashed transition-colors ${
          dragOver
            ? "border-primary bg-primary/5"
            : file
              ? "border-border bg-card"
              : "cursor-pointer border-border bg-card hover:border-primary/50 hover:bg-card-hover"
        } p-8`}
      >
        <input
          ref={fileInputRef}
          type="file"
          accept=".csv"
          className="hidden"
          onChange={(e) => onFileSelect(e.target.files?.[0])}
        />

        {file ? (
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-primary/10">
                <FileIcon className="h-5 w-5 text-primary" />
              </div>
              <div>
                <p className="text-sm font-medium">{file.name}</p>
                <p className="text-xs text-muted">
                  {formatFileSize(file.size)}
                </p>
              </div>
            </div>
            <button
              onClick={(e) => {
                e.stopPropagation();
                onRemoveFile();
              }}
              className="rounded-lg p-2 text-muted transition-colors hover:bg-danger/10 hover:text-danger"
              aria-label="Retirer le fichier"
            >
              <XIcon className="h-4 w-4" />
            </button>
          </div>
        ) : (
          <div className="text-center">
            <UploadCloudIcon className="mx-auto mb-3 h-10 w-10 text-muted/50" />
            <p className="text-sm font-medium text-foreground">
              Glissez-déposez votre fichier CSV ici
            </p>
            <p className="mt-1 text-xs text-muted">
              ou{" "}
              <span className="font-medium text-primary">
                parcourez vos fichiers
              </span>
            </p>
            <p className="mt-2 text-xs text-muted/60">
              Formats supportés : Boursorama, Revolut, Caisse d&#39;Épargne
            </p>
          </div>
        )}
      </div>

      {/* Error */}
      {importError && (
        <div className="rounded-xl border border-danger/30 bg-danger/5 p-4">
          <div className="flex items-start gap-3">
            <XCircleIcon className="mt-0.5 h-4 w-4 shrink-0 text-danger" />
            <div>
              <p className="text-sm font-medium text-danger">{importError}</p>
              <button
                onClick={onUpload}
                className="mt-2 text-sm font-medium text-primary hover:text-primary-hover"
              >
                Réessayer
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Upload button */}
      {file && (
        <div className="flex justify-end">
          <button
            onClick={onUpload}
            disabled={uploading}
            className="flex items-center gap-2 rounded-lg bg-primary px-5 py-2.5 text-sm font-medium text-white transition-colors hover:bg-primary-hover disabled:cursor-not-allowed disabled:opacity-50"
          >
            {uploading ? (
              <>
                <SpinnerIcon className="h-4 w-4 animate-spin" />
                Import en cours…
              </>
            ) : (
              <>
                <UploadIcon className="h-4 w-4" />
                Importer
              </>
            )}
          </button>
        </div>
      )}
    </div>
  );
}

/* ── Step 3: Results ─────────────────────────────────── */

function ResultsStep({
  result,
  accountId,
  onImportAnother,
  onNewAccount,
}: {
  result: Import;
  accountId: string;
  onImportAnother: () => void;
  onNewAccount: () => void;
}) {
  const isFailed = result.status === "failed";
  const hasErrors = result.rows_errored > 0 || (result.error_details?.length ?? 0) > 0;
  const rows: ImportRowDetail[] = result.row_details ?? [];

  return (
    <div className="space-y-4">
      {/* Status banner */}
      <div
        className={`rounded-xl border p-6 ${
          isFailed
            ? "border-danger/30 bg-danger/5"
            : hasErrors
              ? "border-warning/30 bg-warning/5"
              : "border-success/30 bg-success/5"
        }`}
      >
        <div className="flex items-start gap-4">
          {isFailed ? (
            <XCircleIcon className="mt-0.5 h-6 w-6 shrink-0 text-danger" />
          ) : hasErrors ? (
            <ExclamationIcon className="mt-0.5 h-6 w-6 shrink-0 text-warning" />
          ) : (
            <CheckCircleIcon className="mt-0.5 h-6 w-6 shrink-0 text-success" />
          )}
          <div>
            <h2
              className={`text-lg font-semibold ${
                isFailed
                  ? "text-danger"
                  : hasErrors
                    ? "text-warning"
                    : "text-success"
              }`}
            >
              {isFailed
                ? "Import échoué"
                : hasErrors
                  ? "Import terminé avec des avertissements"
                  : "Import réussi"}
            </h2>
            <p className="mt-1 text-sm text-muted">
              {result.filename} — {formatDate(result.inserted_at)}
            </p>
          </div>
        </div>
      </div>

      {/* Summary stats */}
      {!isFailed && (
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
          <StatCard
            label="Total"
            value={result.rows_total}
            variant="default"
          />
          <StatCard
            label="Importées"
            value={result.rows_imported}
            variant="success"
          />
          <StatCard
            label="Ignorées"
            value={result.rows_skipped}
            variant="warning"
          />
          <StatCard
            label="Erreurs"
            value={result.rows_errored}
            variant="danger"
          />
        </div>
      )}

      {/* Transaction details table */}
      {rows.length > 0 && <ImportResultsTable rows={rows} />}

      {/* Fallback: error details for failed imports (no row_details) */}
      {isFailed && rows.length === 0 && (result.error_details?.length ?? 0) > 0 && (
        <div className="rounded-xl border border-border bg-card">
          <div className="border-b border-border px-4 py-3">
            <h3 className="text-sm font-medium">Détails de l&#39;erreur</h3>
          </div>
          <div className="max-h-64 overflow-y-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-border text-left text-xs text-muted">
                  <th className="px-4 py-2 font-medium">Ligne</th>
                  <th className="px-4 py-2 font-medium">Message</th>
                </tr>
              </thead>
              <tbody>
                {result.error_details.map((err, i) => (
                  <tr key={i} className="border-b border-border last:border-0">
                    <td className="whitespace-nowrap px-4 py-2 font-mono text-xs text-muted">
                      {err.row > 0 ? `#${err.row}` : "—"}
                    </td>
                    <td className="px-4 py-2 text-danger">{err.message}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Actions */}
      <div className="flex flex-wrap gap-3">
        {!isFailed && (
          <Link
            href={`/accounts/${accountId}`}
            className="flex items-center gap-2 rounded-lg bg-primary px-5 py-2.5 text-sm font-medium text-white transition-colors hover:bg-primary-hover"
          >
            Voir les transactions
          </Link>
        )}
        <button
          onClick={onImportAnother}
          className="rounded-lg border border-border px-5 py-2.5 text-sm font-medium text-foreground transition-colors hover:bg-card-hover"
        >
          Importer un autre fichier
        </button>
        <button
          onClick={onNewAccount}
          className="text-sm text-muted hover:text-foreground"
        >
          Changer de compte
        </button>
      </div>
    </div>
  );
}

/* ── Import Results Table (Excel-like) ───────────────── */

const STATUS_CONFIG: Record<ImportRowStatus, { label: string; class: string; bg: string }> = {
  added: { label: "Ajoutée", class: "text-success", bg: "bg-success/10" },
  skipped: { label: "Ignorée", class: "text-warning", bg: "bg-warning/10" },
  error: { label: "Erreur", class: "text-danger", bg: "bg-danger/10" },
};

const FILTER_OPTIONS: { value: "all" | ImportRowStatus; label: string }[] = [
  { value: "all", label: "Tout" },
  { value: "added", label: "Ajoutées" },
  { value: "skipped", label: "Ignorées" },
  { value: "error", label: "Erreurs" },
];

function ImportResultsTable({ rows }: { rows: ImportRowDetail[] }) {
  const [filter, setFilter] = useState<"all" | ImportRowStatus>("all");

  const filteredRows = useMemo(
    () => (filter === "all" ? rows : rows.filter((r) => r.status === filter)),
    [rows, filter],
  );

  const counts = useMemo(() => {
    const c = { all: rows.length, added: 0, skipped: 0, error: 0 };
    for (const r of rows) c[r.status]++;
    return c;
  }, [rows]);

  return (
    <div className="rounded-xl border border-border bg-card">
      {/* Toolbar */}
      <div className="flex items-center justify-between border-b border-border px-4 py-3">
        <h3 className="text-sm font-medium">
          Détail des transactions
          <span className="ml-2 text-xs text-muted">
            ({filteredRows.length}{filter !== "all" ? ` / ${rows.length}` : ""})
          </span>
        </h3>
        <div className="flex gap-1">
          {FILTER_OPTIONS.map((opt) => {
            const count = counts[opt.value];
            if (opt.value !== "all" && count === 0) return null;
            return (
              <button
                key={opt.value}
                onClick={() => setFilter(opt.value)}
                className={`rounded-md px-2.5 py-1 text-xs font-medium transition-colors ${
                  filter === opt.value
                    ? "bg-primary/15 text-primary"
                    : "text-muted hover:bg-muted/10 hover:text-foreground"
                }`}
              >
                {opt.label}
                <span className="ml-1 tabular-nums opacity-70">{count}</span>
              </button>
            );
          })}
        </div>
      </div>

      {/* Table */}
      <div className="max-h-[28rem] overflow-auto">
        <table className="w-full border-collapse text-sm">
          <thead className="sticky top-0 z-10 bg-card">
            <tr className="border-b-2 border-border text-left text-xs uppercase tracking-wider text-muted">
              <th className="w-12 px-3 py-2.5 text-center font-semibold">#</th>
              <th className="w-24 px-3 py-2.5 font-semibold">Date</th>
              <th className="px-3 py-2.5 font-semibold">Libellé</th>
              <th className="w-28 px-3 py-2.5 text-right font-semibold">Montant</th>
              <th className="w-32 px-3 py-2.5 font-semibold">Catégorie</th>
              <th className="w-24 px-3 py-2.5 text-center font-semibold">Statut</th>
            </tr>
          </thead>
          <tbody>
            {filteredRows.map((row) => {
              const cfg = STATUS_CONFIG[row.status];
              const amount = parseFloat(row.amount);
              const isNegative = amount < 0;

              return (
                <tr
                  key={row.row}
                  className={`border-b border-border/50 transition-colors hover:bg-muted/5 ${
                    row.status === "error" ? "bg-danger/[0.03]" : ""
                  }`}
                >
                  <td className="px-3 py-2 text-center font-mono text-xs text-muted/70">
                    {row.row}
                  </td>
                  <td className="whitespace-nowrap px-3 py-2 font-mono text-xs">
                    {formatShortDate(row.date)}
                  </td>
                  <td className="max-w-0 truncate px-3 py-2" title={row.label}>
                    <span className="text-foreground">{row.label}</span>
                    {row.error && (
                      <span className="ml-2 text-xs text-danger">{row.error}</span>
                    )}
                  </td>
                  <td
                    className={`whitespace-nowrap px-3 py-2 text-right font-mono text-xs font-medium tabular-nums ${
                      isNegative ? "text-danger" : "text-success"
                    }`}
                  >
                    {isNegative ? "" : "+"}{formatAmount(amount)}
                  </td>
                  <td className="px-3 py-2 text-xs text-muted">
                    {row.category ?? "—"}
                  </td>
                  <td className="px-3 py-2 text-center">
                    <span
                      className={`inline-block rounded-full px-2 py-0.5 text-[11px] font-medium ${cfg.bg} ${cfg.class}`}
                    >
                      {cfg.label}
                    </span>
                  </td>
                </tr>
              );
            })}
            {filteredRows.length === 0 && (
              <tr>
                <td colSpan={6} className="px-3 py-8 text-center text-sm text-muted">
                  Aucune transaction pour ce filtre
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}

function formatShortDate(iso: string): string {
  const d = new Date(iso + "T00:00:00");
  return d.toLocaleDateString("fr-FR", { day: "2-digit", month: "2-digit", year: "numeric" });
}

function formatAmount(n: number): string {
  return new Intl.NumberFormat("fr-FR", {
    style: "currency",
    currency: "EUR",
    minimumFractionDigits: 2,
  }).format(n);
}

/* ── Stat Card ───────────────────────────────────────── */

const STAT_VARIANTS: Record<string, string> = {
  default: "text-foreground",
  success: "text-success",
  warning: "text-warning",
  danger: "text-danger",
};

function StatCard({
  label,
  value,
  variant,
}: {
  label: string;
  value: number;
  variant: string;
}) {
  return (
    <div className="rounded-xl border border-border bg-card p-4 text-center">
      <p className={`text-2xl font-bold tabular-nums ${STAT_VARIANTS[variant] ?? ""}`}>
        {value}
      </p>
      <p className="mt-1 text-xs text-muted">{label}</p>
    </div>
  );
}

/* ── Icons ────────────────────────────────────────────── */

function CheckIcon({ className }: { className?: string }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
      <path strokeLinecap="round" strokeLinejoin="round" d="m4.5 12.75 6 6 9-13.5" />
    </svg>
  );
}

function CheckCircleIcon({ className }: { className?: string }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M9 12.75 11.25 15 15 9.75M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" />
    </svg>
  );
}

function XCircleIcon({ className }: { className?: string }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
      <path strokeLinecap="round" strokeLinejoin="round" d="m9.75 9.75 4.5 4.5m0-4.5-4.5 4.5M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" />
    </svg>
  );
}

function ExclamationIcon({ className }: { className?: string }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126ZM12 15.75h.007v.008H12v-.008Z" />
    </svg>
  );
}

function BankIcon({ className }: { className?: string }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M12 21v-8.25M15.75 21v-8.25M8.25 21v-8.25M3 9l9-6 9 6m-1.5 12V10.332A48.36 48.36 0 0 0 12 9.75c-2.551 0-5.056.2-7.5.582V21M3 21h18M12 6.75h.008v.008H12V6.75Z" />
    </svg>
  );
}

function UploadCloudIcon({ className }: { className?: string }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M12 16.5V9.75m0 0 3 3m-3-3-3 3M6.75 19.5a4.5 4.5 0 0 1-1.41-8.775 5.25 5.25 0 0 1 10.233-2.33 3 3 0 0 1 3.758 3.848A3.752 3.752 0 0 1 18 19.5H6.75Z" />
    </svg>
  );
}

function UploadIcon({ className }: { className?: string }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M3 16.5v2.25A2.25 2.25 0 0 0 5.25 21h13.5A2.25 2.25 0 0 0 21 18.75V16.5m-13.5-9L12 3m0 0 4.5 4.5M12 3v13.5" />
    </svg>
  );
}

function FileIcon({ className }: { className?: string }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 0 0-3.375-3.375h-1.5A1.125 1.125 0 0 1 13.5 7.125v-1.5a3.375 3.375 0 0 0-3.375-3.375H8.25m2.25 0H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 0 0-9-9Z" />
    </svg>
  );
}

function XIcon({ className }: { className?: string }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M6 18 18 6M6 6l12 12" />
    </svg>
  );
}

function SpinnerIcon({ className }: { className?: string }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24">
      <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
      <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z" />
    </svg>
  );
}
