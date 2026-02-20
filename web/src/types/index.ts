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

export interface TagRef {
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
  tags: TagRef[];
  bank_reference: string | null;
  source: TransactionSource;
}

/* ── Tag ─────────────────────────────────────────────── */

export interface Tag {
  id: string;
  name: string;
  color: string; // hex color
  inserted_at: string;
  updated_at: string;
}

/* ── Tagging Rule ────────────────────────────────────── */

export interface TaggingRule {
  id: string;
  keyword: string;
  tag_id: string;
  tag: Tag | null;
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

export type ImportRowStatus = "added" | "skipped" | "error";

export interface ImportRowDetail {
  row: number;
  date: string;
  label: string;
  amount: string;
  tags: string | null;
  status: ImportRowStatus;
  error?: string;
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
  row_details?: ImportRowDetail[];
  inserted_at: string;
  updated_at: string;
}

/* ── Dashboard ───────────────────────────────────────── */

export interface DashboardSummary {
  net_worth: string;
  currency: string;
  accounts: {
    id: string;
    name: string;
    bank: string;
    type: AccountType;
    balance: string;
    last_import_at: string | null;
  }[];
}

export interface SpendingTag {
  tag: string;
  color: string;
  amount: string;
  percentage: number;
}

export interface DashboardSpending {
  month: string;
  total_expenses: string;
  total_income: string;
  by_tag: SpendingTag[];
}

export interface MonthlyTrend {
  month: string;
  income: string;
  expenses: string;
  net: string;
}

export interface DashboardTrends {
  months: MonthlyTrend[];
}

export interface TopExpense {
  id: string;
  date: string;
  label: string;
  amount: string;
  tags: string[];
  account: string;
}

export interface DashboardTopExpenses {
  month: string;
  expenses: TopExpense[];
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
