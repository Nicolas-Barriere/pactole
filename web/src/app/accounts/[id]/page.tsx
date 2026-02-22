import { notFound } from "next/navigation";
import { serverApi } from "@/lib/server-api";
import { AccountDetailPageClient } from "@/components/account-detail-page-client";
import type { Account, Transaction, Import, PaginatedResponse } from "@/types";

interface ImportsListResponse {
  data: Import[];
}

function fallbackOutcomes(imp: Import) {
  return {
    added: imp.rows_imported,
    updated: 0,
    ignored: imp.rows_skipped,
    error: imp.rows_errored,
  };
}

/* ── Page (Server Component) ─────────────────────────── */

export default async function AccountDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;

  let account: Account;
  let transactions: Transaction[] = [];
  let imports: Import[] = [];
  let importsError = false;

  try {
    account = await serverApi.get<Account>(`/accounts/${id}`);
  } catch {
    notFound();
  }

  try {
    const res = await serverApi.get<PaginatedResponse<Transaction>>(
      `/accounts/${id}/transactions?per_page=20`,
    );
    transactions = res.data ?? [];
  } catch {
    /* non-critical */
  }

  try {
    const response = await serverApi.get<ImportsListResponse>(`/accounts/${id}/imports`);
    const importList = Array.isArray(response.data) ? response.data : [];

    const enriched = await Promise.all(
      importList.map(async (imp) => {
        try {
          const detailed = await serverApi.get<Import>(`/imports/${imp.id}`);
          return {
            ...imp,
            outcomes: detailed.outcomes ?? fallbackOutcomes(imp),
          };
        } catch {
          return {
            ...imp,
            outcomes: fallbackOutcomes(imp),
          };
        }
      }),
    );

    imports = enriched.sort(
      (a, b) => new Date(b.inserted_at).getTime() - new Date(a.inserted_at).getTime(),
    );
  } catch {
    importsError = true;
  }

  return (
    <AccountDetailPageClient
      account={account}
      transactions={transactions}
      imports={imports}
      importsError={importsError}
    />
  );
}
