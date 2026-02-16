export default function TransactionsPage() {
  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold tracking-tight">Transactions</h1>
        <p className="text-sm text-muted">
          Toutes vos transactions, tous comptes confondus
        </p>
      </div>

      <div className="rounded-xl border border-dashed border-border bg-card p-12 text-center text-sm text-muted">
        Aucune transaction pour le moment. Importez un fichier CSV pour
        commencer.
      </div>
    </div>
  );
}
