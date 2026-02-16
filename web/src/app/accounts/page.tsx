export default function AccountsPage() {
  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold tracking-tight">Comptes</h1>
        <p className="text-sm text-muted">Gérez vos comptes bancaires</p>
      </div>

      <div className="rounded-xl border border-dashed border-border bg-card p-12 text-center text-sm text-muted">
        Aucun compte pour le moment. Créez votre premier compte pour commencer.
      </div>
    </div>
  );
}
