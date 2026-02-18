import {
  PageSkeleton,
  SkeletonCard,
  SkeletonChart,
} from "@/components/skeleton";

export default function DashboardLoading() {
  return (
    <PageSkeleton>
      <SkeletonCard />

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        <SkeletonCard />
        <SkeletonCard />
        <SkeletonCard />
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        <SkeletonChart />
        <SkeletonChart />
      </div>
    </PageSkeleton>
  );
}
