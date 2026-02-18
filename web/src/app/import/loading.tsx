export default function ImportLoading() {
  return (
    <div className="space-y-6">
      <div>
        <div className="h-7 w-32 animate-skeleton rounded bg-muted/20" />
        <div className="mt-1.5 h-4 w-64 animate-skeleton rounded bg-muted/20" />
      </div>

      {/* Stepper skeleton */}
      <div className="flex items-center gap-2">
        {Array.from({ length: 3 }).map((_, i) => (
          <div key={i} className="flex items-center gap-2">
            {i > 0 && <div className="h-px w-8 bg-border" />}
            <div className="flex items-center gap-2">
              <div className="h-7 w-7 animate-skeleton rounded-full bg-muted/20" />
              <div className="h-4 w-14 animate-skeleton rounded bg-muted/20" />
            </div>
          </div>
        ))}
      </div>

      {/* Card skeleton */}
      <div className="rounded-xl border border-border bg-card p-6">
        <div className="space-y-4">
          <div className="h-5 w-48 animate-skeleton rounded bg-muted/20" />
          <div className="h-10 w-full animate-skeleton rounded-lg bg-muted/20" />
          <div className="flex justify-between">
            <div className="h-4 w-32 animate-skeleton rounded bg-muted/20" />
            <div className="h-9 w-24 animate-skeleton rounded-lg bg-muted/20" />
          </div>
        </div>
      </div>
    </div>
  );
}
