import { Suspense } from "react";
import { serverApi } from "@/lib/server-api";
import { ImportWizard } from "@/components/import-wizard";
import type { Account } from "@/types";

/* ── Page (Server Component) ─────────────────────────── */

async function ImportContent() {
  let accounts: Account[] = [];

  try {
    accounts = await serverApi.get<Account[]>("/accounts");
  } catch {
    /* silently fail — wizard handles empty state */
  }

  return <ImportWizard accounts={accounts} />;
}

export default function ImportPage() {
  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold tracking-tight">Importer</h1>
        <p className="text-sm text-muted-foreground">
          Importez vos relevés bancaires au format CSV
        </p>
      </div>

      <Suspense
        fallback={
          <div className="border border-border bg-card p-6">
            <div className="space-y-4">
              <div className="h-5 w-48 animate-pulse bg-muted/20" />
              <div className="h-10 w-full animate-pulse bg-muted/20" />
            </div>
          </div>
        }
      >
        <ImportContent />
      </Suspense>
    </div>
  );
}
