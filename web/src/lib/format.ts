export function formatAmount(amount: string, currency: string): string {
  return new Intl.NumberFormat("fr-FR", {
    style: "currency",
    currency,
  }).format(parseFloat(amount));
}
