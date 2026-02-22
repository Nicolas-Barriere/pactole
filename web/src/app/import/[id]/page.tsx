import Link from "next/link";
import { notFound } from "next/navigation";
import { ArrowLeft, FileText } from "lucide-react";
import { serverApi } from "@/lib/server-api";
import { Badge } from "@/components/ui/badge";
import { formatAmount } from "@/lib/format";
import type { Import, ImportRowDetail } from "@/types";

function formatDateTime(iso: string): string {
  return new Intl.DateTimeFormat("fr-FR", {
    day: "numeric",
    month: "short",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  }).format(new Date(iso));
}

const IMPORT_STATUS_LABELS: Record<string, string> = {
  completed: "Termine",
  processing: "En cours",
  pending: "En attente",
  failed: "Echoue",
};

const IMPORT_STATUS_VARIANT: Record<
  string,
  "success" | "warning" | "default" | "destructive"
> = {
  completed: "success",
  processing: "warning",
  pending: "default",
  failed: "destructive",
};

function getRowStatusLabel(row: ImportRowDetail): string {
  if (row.status === "error") return "Erreur";
  if (row.status === "ignored") return "Ignorée";
  if (row.is_replaced) return "Remplacée";
  return "Active";
}

function getRowStatusClass(row: ImportRowDetail): string {
  if (row.status === "error") return "bg-destructive/10 text-destructive";
  if (row.status === "ignored") return "bg-warning/10 text-warning";
  if (row.is_replaced) return "bg-primary/10 text-primary";
  return "bg-success/10 text-success";
}

export default async function ImportDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;

  let importData: Import;
  try {
    importData = await serverApi.get<Import>(`/imports/${id}`);
  } catch {
    notFound();
  }

  const outcomes = importData.outcomes ?? {
    added: importData.rows_imported,
    updated: 0,
    ignored: importData.rows_skipped,
    error: importData.rows_errored,
  };

  const rows = importData.row_details ?? [];

  return (
    <div className="space-y-6">
      <Link
        href="/import"
        className="inline-flex items-center gap-1.5 text-sm text-muted-foreground transition-colors hover:text-foreground"
      >
        <ArrowLeft className="h-4 w-4" />
        Imports CSV
      </Link>

      <section className="border border-border bg-card p-6">
        <div className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
          <div>
            <div className="mb-2 flex items-center gap-2">
              <Badge variant={IMPORT_STATUS_VARIANT[importData.status] ?? "default"}>
                {IMPORT_STATUS_LABELS[importData.status] ?? importData.status}
              </Badge>
              <span className="text-xs text-muted-foreground">
                {formatDateTime(importData.inserted_at)}
              </span>
            </div>
            <h1 className="flex items-center gap-2 text-xl font-bold tracking-tight">
              <FileText className="h-5 w-5 text-muted-foreground" />
              <span className="font-mono text-sm">{importData.filename}</span>
            </h1>
            {importData.account_id && (
              <p className="mt-2 text-sm text-muted-foreground">
                Compte:{" "}
                <Link
                  href={`/accounts/${importData.account_id}`}
                  className="font-medium text-primary hover:text-primary/80"
                >
                  {importData.account_name ?? "Voir le compte"}
                </Link>
              </p>
            )}
          </div>
        </div>

        <div className="mt-5 grid grid-cols-2 gap-3 sm:grid-cols-4">
          <div className="border border-border p-3 text-center">
            <p className="text-lg font-semibold tabular-nums">{importData.rows_total}</p>
            <p className="text-xs text-muted-foreground">Total</p>
          </div>
          <div className="border border-border p-3 text-center">
            <p className="text-lg font-semibold text-success tabular-nums">{outcomes.added}</p>
            <p className="text-xs text-muted-foreground">Ajoutées</p>
          </div>
          <div className="border border-border p-3 text-center">
            <p className="text-lg font-semibold text-primary tabular-nums">{outcomes.updated}</p>
            <p className="text-xs text-muted-foreground">Remplacées à l&apos;import</p>
          </div>
          <div className="border border-border p-3 text-center">
            <p className="text-lg font-semibold text-warning tabular-nums">{outcomes.ignored}</p>
            <p className="text-xs text-muted-foreground">Ignorées</p>
          </div>
        </div>
      </section>

      <section className="overflow-hidden border border-border bg-card">
        <div className="border-b border-border px-4 py-3">
          <h2 className="text-sm font-semibold">Transactions de ce CSV</h2>
        </div>

        {rows.length === 0 ? (
          <div className="p-8 text-center text-sm text-muted-foreground">
            Aucun détail de ligne disponible pour cet import.
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-border text-left text-xs text-muted-foreground">
                  <th className="px-4 py-3 font-medium">#</th>
                  <th className="px-4 py-3 font-medium">Date</th>
                  <th className="px-4 py-3 font-medium">Libellé</th>
                  <th className="px-4 py-3 text-right font-medium">Montant</th>
                  <th className="px-4 py-3 font-medium">Statut</th>
                  <th className="px-4 py-3 font-medium">Remplacée par</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((row) => (
                  <tr
                    key={`${row.row}-${row.date}-${row.amount}-${row.label}`}
                    className="border-b border-border last:border-0"
                  >
                    <td className="px-4 py-3 font-mono text-xs text-muted-foreground">
                      {row.row}
                    </td>
                    <td className="whitespace-nowrap px-4 py-3 text-muted-foreground">
                      {new Date(row.date + "T00:00:00").toLocaleDateString("fr-FR")}
                    </td>
                    <td className="px-4 py-3">
                      <span>{row.label}</span>
                      {row.error && (
                        <span className="ml-2 text-xs text-destructive">{row.error}</span>
                      )}
                    </td>
                    <td className="whitespace-nowrap px-4 py-3 text-right font-mono tabular-nums">
                      {formatAmount(row.amount)}
                    </td>
                    <td className="px-4 py-3">
                      <span className={`px-2 py-0.5 text-xs font-medium ${getRowStatusClass(row)}`}>
                        {getRowStatusLabel(row)}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-xs">
                      {row.replaced_by_import_id ? (
                        <Link
                          href={`/import/${row.replaced_by_import_id}`}
                          className="font-medium text-primary hover:text-primary/80"
                        >
                          {row.replaced_by_import_filename ?? "Voir l'import remplaçant"}
                        </Link>
                      ) : (
                        <span className="text-muted-foreground/60">—</span>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </div>
  );
}
