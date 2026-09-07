/**
 * Money rendering matches the app (WP-66, § 6.4–6.6): the currency code is
 * always shown, a missing price is `Consultar precio` — strictly never `$0`
 * — and USD and MXN are rendered on separate lines, never mixed.
 */
export function formatUsdPrice(price: { readonly amount: number } | null): string {
  if (price === null) return 'Consultar precio';
  return `USD ${price.amount.toFixed(2)}`;
}

export function formatMxnPrice(price: { readonly amount: number } | null): string {
  if (price === null) return '—';
  return `MXN ${price.amount.toFixed(2)}`;
}
