/* ── Account ─────────────────────────────────────────── */

export type AccountType = "checking" | "savings" | "brokerage" | "crypto";

export interface Account {
  id: string;
  name: string;
  bank: string;
  type: AccountType;
  initial_balance: string; // Decimal as string from backend
  currency: string;
  archived: boolean;
  balance: string; // computed: initial_balance + sum(transactions)
  transaction_count: number;
  last_import_at: string | null;
  inserted_at: string;
  updated_at: string;
}

/* ── Transaction ─────────────────────────────────────── */

export type TransactionSource = "csv_import" | "manual";

export interface AccountRef {
  id: string;
  name: string;
  bank: string;
  type: AccountType;
}

export interface CategoryRef {
  id: string;
  name: string;
  color: string;
}

export interface Transaction {
  id: string;
  account_id: string;
  account: AccountRef | null;
  date: string;
  label: string;
  original_label: string;
  amount: string; // Decimal as string — negative = expense, positive = income
  currency: string;
  category_id: string | null;
  category: CategoryRef | null;
  bank_reference: string | null;
  source: TransactionSource;
}

/* ── Category ────────────────────────────────────────── */

export interface Category {
  id: string;
  name: string;
  color: string; // hex color
  inserted_at: string;
  updated_at: string;
}

/* ── Categorization Rule ─────────────────────────────── */

export interface CategorizationRule {
  id: string;
  keyword: string;
  category_id: string;
  category: Category | null;
  priority: number;
  inserted_at: string;
  updated_at: string;
}

/* ── Import ──────────────────────────────────────────── */

export type ImportStatus = "pending" | "processing" | "completed" | "failed";

export interface ImportError {
  row: number;
  message: string;
}

export interface Import {
  id: string;
  account_id: string;
  filename: string;
  rows_total: number;
  rows_imported: number;
  rows_skipped: number;
  rows_errored: number;
  status: ImportStatus;
  error_details: ImportError[];
  inserted_at: string;
  updated_at: string;
}

/* ── Dashboard ───────────────────────────────────────── */

export interface DashboardSummary {
  net_worth: string;
  accounts: Pick<Account, "id" | "name" | "bank" | "type" | "balance" | "currency" | "last_import_at">[];
}

export interface SpendingByCategory {
  category_id: string;
  category_name: string;
  category_color: string;
  total: string;
}

export interface MonthlyTrend {
  month: string; // "2026-01"
  income: string;
  expenses: string;
}

export interface TopExpense {
  id: string;
  date: string;
  label: string;
  amount: string;
  category_name: string | null;
}

/* ── Paginated Response ──────────────────────────────── */

export interface PaginatedResponse<T> {
  data: T[];
  meta: {
    page: number;
    per_page: number;
    total_count: number;
    total_pages: number;
  };
}
