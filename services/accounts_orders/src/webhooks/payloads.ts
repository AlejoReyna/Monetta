/**
 * Shopify's own webhook payload shapes (Admin REST format) — deliberately
 * kept separate from `domain/types.ts`'s mirrored shapes. Only the fields
 * this service actually reads are typed; everything else is left as
 * `unknown` rather than guessed at, since a wrong guess here fails silently
 * (a webhook that parses "successfully" into the wrong shape) rather than
 * loudly.
 */

export interface ShopifyOrderWebhookPayload {
  readonly id: number;
  /** Comma-separated in Shopify's REST payload — not an array. */
  readonly tags?: string;
  readonly financial_status?: string | null;
  readonly fulfillment_status?: string | null;
  /**
   * Gateway names only. Card numbers and `payment_details` are intentionally
   * untyped so this service never reads them.
   */
  readonly payment_gateway_names?: readonly string[] | string | null;
  /** Deprecated Shopify order field; same role as one gateway name. */
  readonly gateway?: string | null;
  readonly transactions?: ReadonlyArray<{
    readonly kind?: string | null;
    readonly gateway?: string | null;
    readonly type?: string | null;
    readonly formatted_gateway?: string | null;
    readonly formattedGateway?: string | null;
  }> | null;
  readonly current_total_price?: string | null;
  readonly currency?: string | null;
  readonly created_at?: string | null;
  /** Shopify's order updated_at — used for out-of-order protection (F15). */
  readonly updated_at?: string | null;
  readonly customer?: {
    readonly id: number;
    readonly email?: string | null;
    readonly first_name?: string | null;
    readonly last_name?: string | null;
    readonly phone?: string | null;
  } | null;
  /**
   * Cart attributes (`CartAttribution.toAttributeInputs()` in
   * `lib/data/shopify/cart_attribution.dart`) survive checkout as
   * `note_attributes` on the resulting order.
   */
  readonly note_attributes?: ReadonlyArray<{ readonly name: string; readonly value: string }>;
}

export interface ShopifyCustomerRedactWebhookPayload {
  readonly customer: { readonly id: number };
}

export interface ShopifyCustomerDataRequestWebhookPayload {
  readonly customer: { readonly id: number };
}

export interface ShopifyShopRedactWebhookPayload {
  readonly shop_id: number;
  readonly shop_domain?: string;
}

export interface ShopifyProductWebhookPayload {
  readonly id: number;
  readonly title?: string;
  readonly vendor?: string;
  readonly product_type?: string;
  readonly updated_at?: string;
  readonly image?: { readonly src?: string | null } | null;
  readonly images?: ReadonlyArray<{ readonly src?: string | null }>;
  readonly variants?: ReadonlyArray<{
    readonly price?: string | null;
    readonly inventory_quantity?: number | null;
    readonly inventory_policy?: string | null;
  }>;
}

export function noteAttribute(
  payload: ShopifyOrderWebhookPayload,
  name: string,
): string | null {
  return payload.note_attributes?.find((a) => a.name === name)?.value ?? null;
}

export function parseTags(tags: string | undefined): string[] {
  if (!tags) return [];
  return tags
    .split(',')
    .map((t) => t.trim())
    .filter((t) => t.length > 0);
}
