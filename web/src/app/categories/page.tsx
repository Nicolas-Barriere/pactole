export default function CategoriesPage() {
  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold tracking-tight">Catégories</h1>
        <p className="text-sm text-muted">
          Gérez vos catégories et règles de catégorisation
        </p>
      </div>

      <div className="rounded-xl border border-dashed border-border bg-card p-12 text-center text-sm text-muted">
        Les catégories par défaut seront créées automatiquement.
      </div>
    </div>
  );
}
