import { Suspense } from "react";
import { serverApi } from "@/lib/server-api";
import { TransactionsClient } from "@/components/transactions-client";
import type { Account, Tag, Transaction, PaginatedResponse } from "@/types";

const PER_PAGE = 50;

/* ── Page (Server Component) ─────────────────────────── */

async function TransactionsContent({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  const params = await searchParams;

  const page = Number(singleParam(params.page)) || 1;
  const search = singleParam(params.search);
  const accountFilters = parseMultiParam(params.account);
  const importFilter = singleParam(params.import);
  const tagFilters = parseMultiParam(params.tag);
  const dateFrom = singleParam(params.from);
  const dateTo = singleParam(params.to);
  const sortBy = singleParam(params.sort) || "date";
  const sortOrder = singleParam(params.order) || "desc";

  /* Build query string for transactions */
  const q = new URLSearchParams();
  q.set("page", String(page));
  q.set("per_page", String(PER_PAGE));
  if (search) q.set("search", search);
  if (accountFilters.length > 0) q.set("account_ids", accountFilters.join(","));
  if (importFilter) q.set("import_id", importFilter);
  if (tagFilters.length > 0) q.set("tag_ids", tagFilters.join(","));
  if (dateFrom) q.set("date_from", dateFrom);
  if (dateTo) q.set("date_to", dateTo);
  q.set("sort_by", sortBy);
  q.set("sort_order", sortOrder);

  let initialData: PaginatedResponse<Transaction> = {
    data: [],
    meta: { page: 1, per_page: PER_PAGE, total_count: 0, total_pages: 0 },
  };
  let accounts: Account[] = [];
  let tags: Tag[] = [];

  try {
    [initialData, accounts, tags] = await Promise.all([
      serverApi.get<PaginatedResponse<Transaction>>(
        `/transactions?${q.toString()}`,
      ),
      serverApi.get<Account[]>("/accounts"),
      serverApi.get<Tag[]>("/tags"),
    ]);
  } catch {
    /* silently fail — show empty state */
  }

  return (
    <TransactionsClient
      initialData={initialData}
      accounts={accounts}
      tags={tags}
      searchParamsObj={{
        page,
        search,
        accountFilters,
        importFilter,
        tagFilters,
        dateFrom,
        dateTo,
        sortBy,
        sortOrder,
      }}
    />
  );
}

export default function TransactionsPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  return (
    <Suspense fallback={<TransactionsSkeleton />}>
      <TransactionsContent searchParams={searchParams} />
    </Suspense>
  );
}

function singleParam(value: string | string[] | undefined): string {
  if (Array.isArray(value)) return value.at(-1) ?? "";
  return value ?? "";
}

function parseMultiParam(value: string | string[] | undefined): string[] {
  const raw = singleParam(value);
  if (!raw || raw === "_all") return [];
  return raw
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);
}

/* ── Loading Skeleton ────────────────────────────────── */

function TransactionsSkeleton() {
  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <div className="space-y-2">
          <div className="h-7 w-40 animate-pulse bg-muted/20" />
          <div className="h-4 w-72 animate-pulse bg-muted/20" />
        </div>
        <div className="h-9 w-52 animate-pulse bg-muted/20" />
      </div>
      <div className="flex gap-3">
        <div className="h-9 flex-1 animate-pulse bg-muted/20" />
        <div className="h-9 w-40 animate-pulse bg-muted/20" />
        <div className="h-9 w-44 animate-pulse bg-muted/20" />
      </div>
      <div className="overflow-hidden border border-border bg-card">
        {Array.from({ length: 8 }).map((_, i) => (
          <div
            key={i}
            className="flex items-center gap-4 border-b border-border px-4 py-4 last:border-0"
          >
            <div className="h-4 w-4 animate-pulse bg-muted/20" />
            <div className="h-3 w-20 animate-pulse bg-muted/20" />
            <div className="h-3 w-44 animate-pulse bg-muted/20" />
            <div className="h-3 w-20 animate-pulse bg-muted/20" />
            <div className="ml-auto h-3 w-20 animate-pulse bg-muted/20" />
            <div className="h-3 w-24 animate-pulse bg-muted/20" />
          </div>
        ))}
      </div>
    </div>
  );
}
