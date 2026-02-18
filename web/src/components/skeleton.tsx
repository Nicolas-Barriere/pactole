import type { ReactNode } from "react";

/* ── Base skeleton block ──────────────────────────────── */

interface SkeletonProps {
  className?: string;
  style?: React.CSSProperties;
}

export function Skeleton({ className = "", style }: SkeletonProps) {
  return (
    <div
      className={`animate-skeleton rounded-md bg-muted/20 ${className}`}
      style={style}
    />
  );
}

/* ── Card skeleton ────────────────────────────────────── */

export function SkeletonCard({ className = "" }: SkeletonProps) {
  return (
    <div className={`rounded-xl border border-border bg-card p-6 ${className}`}>
      <Skeleton className="mb-3 h-3 w-24" />
      <Skeleton className="h-7 w-32" />
    </div>
  );
}

/* ── Table skeleton ───────────────────────────────────── */

export function SkeletonTable({ rows = 5 }: { rows?: number }) {
  return (
    <div className="rounded-xl border border-border bg-card">
      <div className="border-b border-border px-6 py-3">
        <div className="flex gap-6">
          <Skeleton className="h-3 w-20" />
          <Skeleton className="h-3 w-32" />
          <Skeleton className="h-3 w-24" />
          <Skeleton className="h-3 w-16" />
        </div>
      </div>
      {Array.from({ length: rows }).map((_, i) => (
        <div
          key={i}
          className="flex items-center gap-6 border-b border-border px-6 py-4 last:border-0"
        >
          <Skeleton className="h-3 w-20" />
          <Skeleton className="h-3 w-40" />
          <Skeleton className="h-3 w-24" />
          <Skeleton className="h-3 w-16" />
        </div>
      ))}
    </div>
  );
}

/* ── Chart skeleton ───────────────────────────────────── */

export function SkeletonChart({ className = "" }: SkeletonProps) {
  return (
    <div className={`rounded-xl border border-border bg-card p-6 ${className}`}>
      <Skeleton className="mb-6 h-3 w-36" />
      <div className="flex h-48 items-end gap-2">
        {[40, 65, 45, 80, 55, 70, 50, 90, 60, 75, 48, 85].map((h, i) => (
          <Skeleton
            key={i}
            className="flex-1 rounded-t-sm"
            style={{ height: `${h}%` }}
          />
        ))}
      </div>
    </div>
  );
}

/* ── Page-level loading wrapper ───────────────────────── */

interface PageSkeletonProps {
  children: ReactNode;
}

export function PageSkeleton({ children }: PageSkeletonProps) {
  return (
    <div className="space-y-6">
      <div>
        <Skeleton className="mb-2 h-7 w-48" />
        <Skeleton className="h-4 w-64" />
      </div>
      {children}
    </div>
  );
}

/* ── Inline skeleton helper with custom style ─────────── */

export function SkeletonLine({ width = "100%" }: { width?: string }) {
  return <Skeleton className="h-3" style={{ width }} />;
}
