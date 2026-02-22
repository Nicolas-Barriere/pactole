"use client";

import {
  useState,
  useRef,
  useMemo,
  useEffect,
  useCallback,
  type DragEvent,
} from "react";
import Link from "next/link";
import { toast } from "sonner";
import { api, ApiError, importsApi } from "@/lib/api";
import { BANK_LABELS } from "@/lib/account-metadata";
import { formatAmount } from "@/lib/format";
import { Button } from "@/components/ui/button";
import { AccountForm, type AccountFormData } from "@/components/account-form";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { createAccount } from "@/app/actions/accounts";
import type {
  Account,
  Import,
  ImportOutcomes,
  ImportRowDetail,
  ImportRowStatus,
} from "@/types";

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

function formatShortDate(iso: string): string {
  return new Date(iso + "T00:00:00").toLocaleDateString("fr-FR", {
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
  });
}

const IMPORT_STATUS_LABELS: Record<string, string> = {
  completed: "Termine",
  processing: "En cours",
  pending: "En attente",
  failed: "Echoue",
};

const IMPORT_STATUS_CLASS: Record<string, string> = {
  completed: "bg-success/10 text-success",
  processing: "bg-warning/10 text-warning",
  pending: "bg-muted/20 text-muted-foreground",
  failed: "bg-destructive/10 text-destructive",
};

function fallbackOutcomes(imp: Import): ImportOutcomes {
  return {
    added: imp.rows_imported,
    updated: 0,
    ignored: imp.rows_skipped,
    error: imp.rows_errored,
  };
}

/* ── Types ───────────────────────────────────────────── */

// Step 1: upload CSV + detect bank (auto-routes when 1 match)
// Step 2: account selection (only shown when multiple accounts match)
// Step 3: results
type Step = "upload" | "account" | "results";

/* ── Component ───────────────────────────────────────── */

interface ImportWizardProps {
  accounts: Account[];
}

export function ImportWizard({ accounts }: ImportWizardProps) {
  const wizardTopRef = useRef<HTMLDivElement>(null);
  const [availableAccounts, setAvailableAccounts] = useState<Account[]>(accounts);
  const [step, setStep] = useState<Step>("upload");
  const [file, setFile] = useState<File | null>(null);
  const [detecting, setDetecting] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [creatingAccount, setCreatingAccount] = useState(false);
  const [createAccountOpen, setCreateAccountOpen] = useState(false);
  const [dragOver, setDragOver] = useState(false);
  const [detectedBank, setDetectedBank] = useState<string | null>(null);
  const [selectedAccountId, setSelectedAccountId] = useState<string>("");
  const [importResult, setImportResult] = useState<Import | null>(null);
  const [importError, setImportError] = useState<string | null>(null);
  const [timelineItems, setTimelineItems] = useState<Import[]>([]);
  const [timelinePage, setTimelinePage] = useState(1);
  const [timelineHasMore, setTimelineHasMore] = useState(false);
  const [timelineLoading, setTimelineLoading] = useState(false);
  const [timelineError, setTimelineError] = useState<string | null>(null);

  const fileInputRef = useRef<HTMLInputElement>(null);
  const timelineLoadMoreRef = useRef<HTMLDivElement>(null);
  const timelineLoadingRef = useRef(false);
  const selectableAccounts = detectedBank
    ? availableAccounts.filter((a) => a.bank === detectedBank)
    : availableAccounts;
  const selectedAccountLabel = selectedAccountId
    ? (selectableAccounts.find((a) => a.id === selectedAccountId)?.name ??
      "Compte inconnu")
    : "Sélectionnez un compte…";
  const accountNameById = useMemo(
    () => new Map(availableAccounts.map((account) => [account.id, account.name])),
    [availableAccounts],
  );

  const loadTimelinePage = useCallback(
    async (page: number, replace = false) => {
      if (timelineLoadingRef.current) return;

      timelineLoadingRef.current = true;
      setTimelineLoading(true);
      setTimelineError(null);

      try {
        const response = await importsApi.list(page, 20);
        const incoming = Array.isArray(response.data) ? response.data : [];

        setTimelineItems((previous) => {
          if (replace) return incoming;
          const known = new Set(previous.map((item) => item.id));
          const uniqueIncoming = incoming.filter((item) => !known.has(item.id));
          return [...previous, ...uniqueIncoming];
        });

        const totalPages = response.meta?.total_pages ?? page;
        setTimelinePage(page);
        setTimelineHasMore(page < totalPages);
      } catch {
        setTimelineError("Impossible de charger l'historique global.");
      } finally {
        timelineLoadingRef.current = false;
        setTimelineLoading(false);
      }
    },
    [],
  );

  useEffect(() => {
    void loadTimelinePage(1, true);
  }, [loadTimelinePage]);

  useEffect(() => {
    const target = timelineLoadMoreRef.current;
    if (!target || !timelineHasMore) return;

    const observer = new IntersectionObserver(
      (entries) => {
        const first = entries[0];
        if (!first?.isIntersecting) return;
        void loadTimelinePage(timelinePage + 1);
      },
      { rootMargin: "240px 0px" },
    );

    observer.observe(target);
    return () => observer.disconnect();
  }, [timelineHasMore, timelinePage, loadTimelinePage]);

  function prependToTimeline(importData: Import, accountId: string) {
    const accountName = accountNameById.get(accountId) ?? null;
    const nextItem: Import = { ...importData, account_name: accountName };

    setTimelineItems((previous) => {
      const deduped = previous.filter((item) => item.id !== nextItem.id);
      return [nextItem, ...deduped];
    });
  }

  /* ── File handling + bank detection ────────────────── */

  async function detectBankAndRoute(selected: File | undefined) {
    if (!selected) return;
    if (!selected.name.toLowerCase().endsWith(".csv")) {
      toast.error("Seuls les fichiers .csv sont acceptés");
      return;
    }
    if (selected.size === 0) {
      toast.error("Le fichier est vide");
      return;
    }

    setFile(selected);
    setImportError(null);
    setDetecting(true);

    try {
      const formData = new FormData();
      formData.append("file", selected);
      const res = await api.upload<{ data: { detected_bank: string } }>(
        "/imports/detect",
        formData,
      );
      const bank = res.data.detected_bank;
      setDetectedBank(bank);

      const matching = availableAccounts.filter((a) => a.bank === bank);

      if (matching.length === 0) {
        toast.info("Aucun compte trouvé pour cette banque. Veuillez le créer.");
        setCreateAccountOpen(true);
      } else if (matching.length === 1) {
        // Auto-select and upload immediately
        const accountId = matching[0].id;
        setSelectedAccountId(accountId);
        await executeUpload(selected, accountId);
      } else {
        // Multiple matches — let user pick
        setStep("account");
      }
    } catch (err) {
      setFile(null);
      if (err instanceof ApiError && err.status === 422) {
        toast.error("Format CSV non reconnu ou banque non supportée");
      } else {
        toast.error("Erreur de connexion");
      }
    } finally {
      setDetecting(false);
    }
  }

  async function handleCreateAccount(data: AccountFormData) {
    try {
      setCreatingAccount(true);
      const result = await createAccount(data);
      if (!result.success) {
        toast.error(result.error);
        return;
      }
      if (!result.data) {
        toast.error("Impossible de créer le compte");
        return;
      }

      const createdAccount = result.data;
      setAvailableAccounts((prev) => [...prev, createdAccount]);
      setSelectedAccountId(createdAccount.id);
      setCreateAccountOpen(false);
      toast.success("Compte créé avec succès");

      if (file) {
        await executeUpload(file, createdAccount.id);
      }
    } finally {
      setCreatingAccount(false);
    }
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
    detectBankAndRoute(e.dataTransfer.files[0]);
  }

  /* ── Upload ────────────────────────────────────────── */

  async function executeUpload(fileToUpload: File, accountId: string) {
    try {
      setUploading(true);
      setImportError(null);
      const formData = new FormData();
      formData.append("file", fileToUpload);
      const result = await api.upload<Import>(
        `/accounts/${accountId}/imports`,
        formData,
      );
      setImportResult(result);
      prependToTimeline(result, accountId);
      setStep("results");
      toast.success("Import terminé avec succès");
    } catch (err) {
      if (err instanceof ApiError) {
        const body = err.body as Import | { errors?: { detail?: string } } | null;
        if (body && "status" in body && (body as Import).status === "failed") {
          setImportResult(body as Import);
          setStep("results");
          return;
        }
        const errorBody = body as { errors?: { detail?: string } } | null;
        setImportError(errorBody?.errors?.detail ?? "Erreur lors de l'import");
      } else {
        setImportError("Erreur de connexion. Veuillez réessayer.");
      }
    } finally {
      setUploading(false);
    }
  }

  /* ── Stepper ───────────────────────────────────────── */

  const STEPS: { key: Step; label: string }[] = [
    { key: "upload", label: "Fichier" },
    { key: "account", label: "Compte" },
    { key: "results", label: "Résultat" },
  ];
  const currentIndex = STEPS.findIndex((s) => s.key === step);

  function scrollToImportTop() {
    const main = document.querySelector("main");
    if (main instanceof HTMLElement) {
      main.scrollTo({ top: 0, behavior: "smooth" });
      return;
    }
    window.scrollTo({ top: 0, behavior: "smooth" });
  }

  function resetToUploadStep() {
    setFile(null);
    setImportResult(null);
    setImportError(null);
    setDetectedBank(null);
    setStep("upload");
    requestAnimationFrame(scrollToImportTop);
    setTimeout(scrollToImportTop, 60);
  }

  return (
    <div ref={wizardTopRef} className="space-y-6">
      {/* Stepper */}
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
                  className={`flex h-7 w-7 items-center justify-center text-xs font-medium transition-colors ${
                    isActive
                      ? "bg-primary text-primary-foreground"
                      : isDone
                        ? "bg-primary/15 text-primary"
                        : "bg-muted/10 text-muted-foreground"
                  }`}
                >
                  {isDone ? (
                    <svg
                      className="h-3.5 w-3.5"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                      strokeWidth={2.5}
                    >
                      <path
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        d="m4.5 12.75 6 6 9-13.5"
                      />
                    </svg>
                  ) : (
                    i + 1
                  )}
                </span>
                <span
                  className={`text-sm font-medium ${
                    isActive
                      ? "text-foreground"
                      : isDone
                        ? "text-primary"
                        : "text-muted-foreground"
                  }`}
                >
                  {s.label}
                </span>
              </div>
            </div>
          );
        })}
      </div>

      {/* Step 1: Upload + detect */}
      {step === "upload" && (
        <div className="space-y-4">
          {/* Drop zone */}
          <div
            onDragOver={handleDragOver}
            onDragLeave={handleDragLeave}
            onDrop={handleDrop}
            onClick={() => !file && fileInputRef.current?.click()}
            className={`relative border-2 border-dashed transition-colors ${
              dragOver
                ? "border-primary bg-primary/5"
                : file
                  ? "border-border bg-card"
                  : "cursor-pointer border-border bg-card hover:border-primary/50 hover:bg-accent"
            } p-8`}
          >
            <input
              ref={fileInputRef}
              type="file"
              accept=".csv"
              className="hidden"
              onChange={(e) => detectBankAndRoute(e.target.files?.[0])}
            />

            {file ? (
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-3">
                  <div className="flex h-10 w-10 items-center justify-center bg-primary/10">
                    <svg
                      className="h-5 w-5 text-primary"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                      strokeWidth={1.5}
                    >
                      <path
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        d="M19.5 14.25v-2.625a3.375 3.375 0 0 0-3.375-3.375h-1.5A1.125 1.125 0 0 1 13.5 7.125v-1.5a3.375 3.375 0 0 0-3.375-3.375H8.25m2.25 0H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 0 0-9-9Z"
                      />
                    </svg>
                  </div>
                  <div>
                    <p className="text-sm font-medium">{file.name}</p>
                    <p className="text-xs text-muted-foreground">
                      {formatFileSize(file.size)}
                    </p>
                  </div>
                </div>
                <button
                  onClick={(e) => {
                    e.stopPropagation();
                    setFile(null);
                    setImportError(null);
                  }}
                  className="p-2 text-muted-foreground transition-colors hover:bg-destructive/10 hover:text-destructive"
                >
                  <svg
                    className="h-4 w-4"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                    strokeWidth={2}
                  >
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      d="M6 18 18 6M6 6l12 12"
                    />
                  </svg>
                </button>
              </div>
            ) : (
              <div className="text-center">
                <svg
                  className="mx-auto mb-3 h-10 w-10 text-muted-foreground/50"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                  strokeWidth={1.5}
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    d="M12 16.5V9.75m0 0 3 3m-3-3-3 3M6.75 19.5a4.5 4.5 0 0 1-1.41-8.775 5.25 5.25 0 0 1 10.233-2.33 3 3 0 0 1 3.758 3.848A3.752 3.752 0 0 1 18 19.5H6.75Z"
                  />
                </svg>
                <p className="text-sm font-medium">
                  Glissez-déposez votre fichier CSV ici
                </p>
                <p className="mt-1 text-xs text-muted-foreground">
                  ou{" "}
                  <span className="font-medium text-primary">
                    parcourez vos fichiers
                  </span>
                </p>
                <p className="mt-2 text-xs text-muted-foreground/60">
                  Formats supportés : Boursorama, Revolut, Caisse d&#39;Épargne
                </p>
              </div>
            )}
          </div>

          {/* Error */}
          {importError && (
            <div className="border border-destructive/30 bg-destructive/5 p-4">
              <p className="text-sm font-medium text-destructive">
                {importError}
              </p>
              <button
                onClick={() => detectBankAndRoute(file ?? undefined)}
                className="mt-2 text-sm font-medium text-primary hover:text-primary/80"
              >
                Réessayer
              </button>
            </div>
          )}

          {/* Status indicator */}
          {file && (
            <div className="flex justify-end">
              <div
                className={`flex items-center gap-2 px-5 py-2.5 text-sm font-medium text-white transition-colors ${
                  detecting || uploading ? "bg-primary" : "bg-success"
                }`}
              >
                {detecting ? (
                  <>
                    <svg
                      className="h-4 w-4 animate-spin"
                      fill="none"
                      viewBox="0 0 24 24"
                    >
                      <circle
                        className="opacity-25"
                        cx="12"
                        cy="12"
                        r="10"
                        stroke="currentColor"
                        strokeWidth="4"
                      />
                      <path
                        className="opacity-75"
                        fill="currentColor"
                        d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
                      />
                    </svg>
                    Détection de la banque…
                  </>
                ) : uploading ? (
                  <>
                    <svg
                      className="h-4 w-4 animate-spin"
                      fill="none"
                      viewBox="0 0 24 24"
                    >
                      <circle
                        className="opacity-25"
                        cx="12"
                        cy="12"
                        r="10"
                        stroke="currentColor"
                        strokeWidth="4"
                      />
                      <path
                        className="opacity-75"
                        fill="currentColor"
                        d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
                      />
                    </svg>
                    Import en cours…
                  </>
                ) : (
                  <>
                    <svg
                      className="h-4 w-4"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                      strokeWidth={2.5}
                    >
                      <path
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        d="m4.5 12.75 6 6 9-13.5"
                      />
                    </svg>
                    Fichier analysé
                  </>
                )}
              </div>
            </div>
          )}
        </div>
      )}

      {/* Step 2: Account selection (only when multiple accounts match) */}
      {step === "account" && (
        <div className="border border-border bg-card p-6">
          <label
            htmlFor="account-select"
            className="mb-2 block text-sm font-medium"
          >
            Dans quel compte importer ?
          </label>
          <Select
            value={selectedAccountId}
            onValueChange={(value) => setSelectedAccountId(value ?? "")}
          >
            <SelectTrigger id="account-select">
              <SelectValue>{selectedAccountLabel}</SelectValue>
            </SelectTrigger>
            <SelectContent>
              {selectableAccounts.map((a) => (
                <SelectItem key={a.id} value={a.id}>
                  {a.name} — {BANK_LABELS[a.bank] ?? a.bank} ({a.currency})
                </SelectItem>
              ))}
            </SelectContent>
          </Select>

          <div className="mt-4 flex items-center justify-between">
            <button
              onClick={() => {
                setStep("upload");
                setFile(null);
                setDetectedBank(null);
              }}
              className="text-sm text-muted-foreground hover:text-foreground"
            >
              Retour au fichier
            </button>
            <Button
              onClick={() =>
                file && selectedAccountId && executeUpload(file, selectedAccountId)
              }
              disabled={!selectedAccountId || uploading}
            >
              {uploading ? "Import en cours…" : "Continuer"}
            </Button>
          </div>
        </div>
      )}

      {/* Step 3: Results */}
      {step === "results" && importResult && (
        <ResultsStep
          result={importResult}
          accountId={selectedAccountId}
          onImportAnother={resetToUploadStep}
        />
      )}

      <section className="space-y-3 border-t border-border pt-6">
        <div className="flex items-center justify-between">
          <h2 className="text-lg font-semibold">Historique global des imports CSV</h2>
          {timelineLoading && timelineItems.length === 0 && (
            <span className="text-xs text-muted-foreground">Chargement…</span>
          )}
        </div>

        {timelineError && timelineItems.length === 0 ? (
          <div className="border border-dashed border-destructive/40 bg-card p-5 text-sm text-muted-foreground">
            {timelineError}
            <button
              onClick={() => void loadTimelinePage(1, true)}
              className="ml-2 font-medium text-primary hover:text-primary/80"
            >
              Réessayer
            </button>
          </div>
        ) : timelineItems.length === 0 ? (
          <div className="border border-dashed border-border bg-card p-5 text-sm text-muted-foreground">
            Aucun import pour le moment.
          </div>
        ) : (
          <div className="space-y-2">
            {timelineItems.map((item) => {
              const outcomes = item.outcomes ?? fallbackOutcomes(item);
              const accountLabel =
                item.account_name ?? accountNameById.get(item.account_id) ?? "Compte inconnu";

              return (
                <Link
                  key={item.id}
                  href={`/import/${item.id}`}
                  className="block border border-border bg-card p-4 transition-colors hover:bg-accent"
                >
                  <div className="flex flex-col gap-2 sm:flex-row sm:items-start sm:justify-between">
                    <div className="min-w-0">
                      <p className="truncate font-mono text-xs text-muted-foreground">
                        {item.filename}
                      </p>
                      <p className="text-sm font-medium">{accountLabel}</p>
                      <p className="text-xs text-muted-foreground">
                        {formatDate(item.inserted_at)}
                      </p>
                    </div>

                    <div className="text-right">
                      <span
                        className={`inline-flex px-2 py-0.5 text-[11px] font-medium ${
                          IMPORT_STATUS_CLASS[item.status] ?? "bg-muted/20 text-muted-foreground"
                        }`}
                      >
                        {IMPORT_STATUS_LABELS[item.status] ?? item.status}
                      </span>
                      <p className="mt-2 text-xs text-muted-foreground">
                        <span className="text-success">+{outcomes.added} ajoutées</span>
                        <span className="mx-2 text-primary">{outcomes.updated} remplacées</span>
                        <span className="text-warning">{outcomes.ignored} ignorées</span>
                        <span className="mx-2 text-danger">{outcomes.error} erreurs</span>
                      </p>
                    </div>
                  </div>
                </Link>
              );
            })}
          </div>
        )}

        <div ref={timelineLoadMoreRef} className="flex min-h-8 items-center justify-center">
          {timelineLoading && timelineItems.length > 0 && (
            <span className="text-xs text-muted-foreground">Chargement de plus d&apos;imports…</span>
          )}
          {!timelineHasMore && timelineItems.length > 0 && (
            <span className="text-xs text-muted-foreground">Fin de l&apos;historique</span>
          )}
        </div>
      </section>

      <AccountForm
        key={`import-create-${createAccountOpen ? "open" : "closed"}-${detectedBank ?? "none"}`}
        open={createAccountOpen}
        loading={creatingAccount}
        initialBank={detectedBank ?? undefined}
        onSubmit={handleCreateAccount}
        onClose={() => setCreateAccountOpen(false)}
      />
    </div>
  );
}

/* ── Results Step ────────────────────────────────────── */

function ResultsStep({
  result,
  accountId,
  onImportAnother,
}: {
  result: Import;
  accountId: string;
  onImportAnother: () => void;
}) {
  const isFailed = result.status === "failed";
  const hasErrors =
    result.rows_errored > 0 || (result.error_details?.length ?? 0) > 0;
  const rows: ImportRowDetail[] = result.row_details ?? [];

  return (
    <div className="space-y-4">
      <div
        className={`border p-6 ${
          isFailed
            ? "border-destructive/30 bg-destructive/5"
            : hasErrors
              ? "border-warning/30 bg-warning/5"
              : "border-success/30 bg-success/5"
        }`}
      >
        <h2
          className={`text-lg font-semibold ${
            isFailed
              ? "text-destructive"
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
        <p className="mt-1 text-sm text-muted-foreground">
          {result.filename} — {formatDate(result.inserted_at)}
        </p>
      </div>

      {!isFailed && (
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
          {[
            { label: "Total", value: result.rows_total, color: "text-foreground" },
            { label: "Importées", value: result.rows_imported, color: "text-success" },
            { label: "Ignorées", value: result.rows_skipped, color: "text-warning" },
            { label: "Erreurs", value: result.rows_errored, color: "text-danger" },
          ].map((s) => (
            <div
              key={s.label}
              className="border border-border bg-card p-4 text-center"
            >
              <p className={`text-2xl font-bold tabular-nums ${s.color}`}>
                {s.value}
              </p>
              <p className="mt-1 text-xs text-muted-foreground">{s.label}</p>
            </div>
          ))}
        </div>
      )}

      {rows.length > 0 && <ImportResultsTable rows={rows} />}

      {isFailed && rows.length === 0 && (result.error_details?.length ?? 0) > 0 && (
        <div className="border border-border bg-card">
          <div className="border-b border-border px-4 py-3">
            <h3 className="text-sm font-medium">Détails de l&#39;erreur</h3>
          </div>
          <div className="max-h-64 overflow-y-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-border text-left text-xs text-muted-foreground">
                  <th className="px-4 py-2 font-medium">Ligne</th>
                  <th className="px-4 py-2 font-medium">Message</th>
                </tr>
              </thead>
              <tbody>
                {result.error_details.map((err, i) => (
                  <tr key={i} className="border-b border-border last:border-0">
                    <td className="whitespace-nowrap px-4 py-2 font-mono text-xs text-muted-foreground">
                      {err.row > 0 ? `#${err.row}` : "—"}
                    </td>
                    <td className="px-4 py-2 text-destructive">{err.message}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      <div className="flex flex-wrap items-center gap-3">
        {!isFailed && (
          <Link
            href={`/import/${result.id}`}
            className="inline-flex h-9 items-center gap-2 bg-primary px-4 text-sm font-medium text-primary-foreground transition-colors hover:bg-primary/90"
          >
            Voir le détail de l&apos;import
          </Link>
        )}
        {!isFailed && (
          <Link
            href={`/accounts/${accountId}`}
            className="inline-flex h-9 items-center gap-2 border border-border px-4 text-sm font-medium transition-colors hover:bg-accent"
          >
            Voir le compte
          </Link>
        )}
        <Button variant="outline" className="h-9" onClick={onImportAnother}>
          Importer un autre fichier
        </Button>
      </div>
    </div>
  );
}

/* ── Import Results Table ────────────────────────────── */

const STATUS_CONFIG: Record<
  ImportRowStatus,
  { label: string; color: string; bg: string }
> = {
  added: { label: "Ajoutée", color: "text-success", bg: "bg-success/10" },
  updated: { label: "Remplacée", color: "text-primary", bg: "bg-primary/10" },
  ignored: { label: "Ignorée", color: "text-warning", bg: "bg-warning/10" },
  error: { label: "Erreur", color: "text-danger", bg: "bg-danger/10" },
};

const FILTER_OPTIONS: { value: "all" | ImportRowStatus; label: string }[] = [
  { value: "all", label: "Tout" },
  { value: "added", label: "Ajoutées" },
  { value: "updated", label: "Remplacées" },
  { value: "ignored", label: "Ignorées" },
  { value: "error", label: "Erreurs" },
];

function ImportResultsTable({ rows }: { rows: ImportRowDetail[] }) {
  const [filter, setFilter] = useState<"all" | ImportRowStatus>("all");

  const filteredRows = useMemo(
    () => (filter === "all" ? rows : rows.filter((r) => r.status === filter)),
    [rows, filter],
  );

  const counts = useMemo(() => {
    const c = { all: rows.length, added: 0, updated: 0, ignored: 0, error: 0 };
    for (const r of rows) c[r.status]++;
    return c;
  }, [rows]);

  return (
    <div className="border border-border bg-card">
      <div className="flex items-center justify-between border-b border-border px-4 py-3">
        <h3 className="text-sm font-medium">
          Détail des transactions{" "}
          <span className="text-xs text-muted-foreground">
            ({filteredRows.length}
            {filter !== "all" ? ` / ${rows.length}` : ""})
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
                className={`px-2.5 py-1 text-xs font-medium transition-colors ${
                  filter === opt.value
                    ? "bg-primary/15 text-primary"
                    : "text-muted-foreground hover:bg-muted/10 hover:text-foreground"
                }`}
              >
                {opt.label}{" "}
                <span className="tabular-nums opacity-70">{count}</span>
              </button>
            );
          })}
        </div>
      </div>

      <div className="max-h-[28rem] overflow-auto">
        <table className="w-full border-collapse text-sm">
          <thead className="sticky top-0 z-10 bg-card">
            <tr className="border-b-2 border-border text-left text-xs uppercase tracking-wider text-muted-foreground">
              <th className="w-12 px-3 py-2.5 text-center font-semibold">#</th>
              <th className="w-24 px-3 py-2.5 font-semibold">Date</th>
              <th className="px-3 py-2.5 font-semibold">Libellé</th>
              <th className="w-28 px-3 py-2.5 text-right font-semibold">
                Montant
              </th>
              <th className="w-32 px-3 py-2.5 font-semibold">Tags</th>
              <th className="w-24 px-3 py-2.5 text-center font-semibold">
                Statut
              </th>
            </tr>
          </thead>
          <tbody>
            {filteredRows.map((row) => {
              const cfg = STATUS_CONFIG[row.status];
              const amount = parseFloat(row.amount);
              const isNeg = amount < 0;
              return (
                <tr
                  key={row.row}
                  className={`border-b border-border/50 transition-colors hover:bg-muted/5 ${
                    row.status === "error" ? "bg-destructive/[0.03]" : ""
                  }`}
                >
                  <td className="px-3 py-2 text-center font-mono text-xs text-muted-foreground/70">
                    {row.row}
                  </td>
                  <td className="whitespace-nowrap px-3 py-2 font-mono text-xs">
                    {formatShortDate(row.date)}
                  </td>
                  <td className="max-w-0 truncate px-3 py-2" title={row.label}>
                    <span>{row.label}</span>
                    {row.error && (
                      <span className="ml-2 text-xs text-destructive">
                        {row.error}
                      </span>
                    )}
                  </td>
                  <td
                    className={`whitespace-nowrap px-3 py-2 text-right font-mono text-xs font-medium tabular-nums ${
                      isNeg ? "text-danger" : "text-success"
                    }`}
                  >
                    {isNeg ? "" : "+"}
                    {formatAmount(String(amount))}
                  </td>
                  <td className="px-3 py-2 text-xs text-muted-foreground">
                    {row.tags ?? "—"}
                  </td>
                  <td className="px-3 py-2 text-center">
                    <span
                      className={`inline-block px-2 py-0.5 text-[11px] font-medium ${cfg.bg} ${cfg.color}`}
                    >
                      {cfg.label}
                    </span>
                  </td>
                </tr>
              );
            })}
            {filteredRows.length === 0 && (
              <tr>
                <td
                  colSpan={6}
                  className="px-3 py-8 text-center text-sm text-muted-foreground"
                >
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
