export default function DashboardPage() {
  return (
    <div className="space-y-8">
      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold tracking-tight">Tableau de bord</h1>
        <p className="text-sm text-muted">
          Vue d&apos;ensemble de vos finances
        </p>
      </div>

      {/* Net Worth */}
      <div className="rounded-xl border border-border bg-card p-6">
        <p className="text-sm font-medium text-muted">Patrimoine net</p>
        <p className="mt-1 text-3xl font-bold tracking-tight">—</p>
      </div>

      {/* Account Cards */}
      <section>
        <h2 className="mb-4 text-lg font-semibold">Comptes</h2>
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          <div className="rounded-xl border border-dashed border-border bg-card p-6 text-center text-sm text-muted">
            Aucun compte pour le moment.
            <br />
            Ajoutez un compte pour commencer.
          </div>
        </div>
      </section>

      {/* Charts Placeholder */}
      <div className="grid gap-6 lg:grid-cols-2">
        <div className="rounded-xl border border-border bg-card p-6">
          <h3 className="mb-4 text-sm font-semibold text-muted">
            Dépenses par catégorie
          </h3>
          <div className="flex h-48 items-center justify-center text-sm text-muted">
            Graphique à venir
          </div>
        </div>
        <div className="rounded-xl border border-border bg-card p-6">
          <h3 className="mb-4 text-sm font-semibold text-muted">
            Revenus vs Dépenses
          </h3>
          <div className="flex h-48 items-center justify-center text-sm text-muted">
            Graphique à venir
          </div>
        </div>
      </div>
    </div>
  );
}
