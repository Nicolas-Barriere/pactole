export default function TransactionsLoading() {
  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <div className="space-y-2">
          <div className="h-7 w-40 animate-skeleton rounded bg-muted/20" />
          <div className="h-4 w-72 animate-skeleton rounded bg-muted/20" />
        </div>
        <div className="h-9 w-52 animate-skeleton rounded-lg bg-muted/20" />
      </div>
      <div className="flex gap-3">
        <div className="h-9 flex-1 animate-skeleton rounded-lg bg-muted/20" />
        <div className="h-9 w-40 animate-skeleton rounded-lg bg-muted/20" />
        <div className="h-9 w-44 animate-skeleton rounded-lg bg-muted/20" />
        <div className="h-9 w-36 animate-skeleton rounded-lg bg-muted/20" />
        <div className="h-9 w-36 animate-skeleton rounded-lg bg-muted/20" />
      </div>
      <div className="overflow-hidden rounded-xl border border-border bg-card">
        {Array.from({ length: 8 }).map((_, i) => (
          <div
            key={i}
            className="flex items-center gap-4 border-b border-border px-4 py-4 last:border-0"
          >
            <div className="h-4 w-4 animate-skeleton rounded bg-muted/20" />
            <div className="h-3 w-20 animate-skeleton rounded bg-muted/20" />
            <div className="h-3 w-44 animate-skeleton rounded bg-muted/20" />
            <div className="h-3 w-20 animate-skeleton rounded bg-muted/20" />
            <div className="ml-auto h-3 w-20 animate-skeleton rounded bg-muted/20" />
            <div className="h-3 w-24 animate-skeleton rounded bg-muted/20" />
          </div>
        ))}
      </div>
    </div>
  );
}
