import { notFound } from "next/navigation";
import { serverApi } from "@/lib/server-api";
import { AccountDetailPageClient } from "@/components/account-detail-page-client";
import type { Account, Transaction, Import, PaginatedResponse } from "@/types";

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
    const data = await serverApi.get<Import[]>(`/accounts/${id}/imports`);
    imports = Array.isArray(data) ? data : [];
  } catch {
    /* non-critical */
  }

  return (
    <AccountDetailPageClient
      account={account}
      transactions={transactions}
      imports={imports}
    />
  );
}
