import { serverApi } from "@/lib/server-api";
import { TagsManager } from "@/components/tags-manager";
import type { Tag, TaggingRule } from "@/types";

export default async function TagsPage() {
  let tags: Tag[] = [];
  let rules: TaggingRule[] = [];
  let error: string | null = null;

  try {
    [tags, rules] = await Promise.all([
      serverApi.get<Tag[]>("/tags"),
      serverApi.get<TaggingRule[]>("/tagging-rules"),
    ]);
  } catch {
    error = "Impossible de charger les données";
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold tracking-tight">Tags & Règles</h1>
        <p className="text-sm text-muted-foreground">
          Gérez vos tags et les règles d&apos;auto-tagging
        </p>
      </div>

      {error ? (
        <div className="border border-destructive/30 bg-destructive/5 p-6 text-center">
          <p className="text-sm text-destructive">{error}</p>
        </div>
      ) : (
        <TagsManager initialTags={tags} initialRules={rules} />
      )}
    </div>
  );
}
