/** Centavos enteros. Nunca float para contabilidad. */

/** MXN $ -> centavos (redondeo half-up). Acepta numero finito >= 0. */
export function toCents(amountMxn: number): number {
  if (!Number.isFinite(amountMxn) || amountMxn < 0) {
    throw new Error('invalid_amount');
  }
  return Math.round(amountMxn * 100);
}

/** centavos -> "184.00" para presentacion; el simbolo/moneda lo pone el cliente. */
export function centsToMajor(cents: number): string {
  if (!Number.isInteger(cents)) throw new Error('cents_must_be_integer');
  return (cents / 100).toFixed(2);
}

/** "Tienes $184 Monetta disponibles" — formato es-MX sin decimales si es entero. */
export function formatMonettaShort(cents: number): string {
  if (!Number.isInteger(cents) || cents < 0) throw new Error('cents_must_be_integer');
  const major = cents / 100;
  const body = Number.isInteger(major)
    ? major.toLocaleString('es-MX')
    : major.toLocaleString('es-MX', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  return `$${body} Monetta`;
}
