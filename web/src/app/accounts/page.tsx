import { serverApi } from "@/lib/server-api";
import { AccountsPageClient } from "@/components/accounts-page-client";
import type { Account } from "@/types";

/* ── Page (Server Component) ─────────────────────────── */

export default async function AccountsPage() {
  let accounts: Account[] = [];
  let error: string | null = null;

  try {
    accounts = await serverApi.get<Account[]>("/accounts");
  } catch {
    error = "Impossible de charger les comptes";
  }

  return <AccountsPageClient accounts={accounts} error={error} />;
}
