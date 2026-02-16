export default function ImportPage() {
  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold tracking-tight">Importer</h1>
        <p className="text-sm text-muted">
          Importez vos relevés bancaires au format CSV
        </p>
      </div>

      <div className="rounded-xl border border-dashed border-border bg-card p-12 text-center text-sm text-muted">
        Sélectionnez un compte, puis glissez-déposez votre fichier CSV ici.
      </div>
    </div>
  );
}
