/**
 * Adaptador de canje hacia Shopify.
 *
 * Hallazgo verificado (plan real Basic, docs oficiales):
 * - store credit nativo NO permite elegir cantidad parcial -> descartado.
 * - Functions privadas requieren Plus; apps publicas con Functions pueden
 *   funcionar en otros planes, pero no hay proveedor seleccionado ni
 *   compatibilidad asumida.
 * - Codigo de descuento fijo (Basic) es el unico candidato inmediato, con
 *   limitaciones conocidas: el minimo de Shopify aplica al subtotal total
 *   (no al subconjunto elegible), el comprador puede editar el carrito tras
 *   abrir el checkout, y se requiere reconciliacion posterior.
 *
 * Por eso el adaptador informa `guarantees` y el canje vive tras bandera.
 */
export interface DiscountProvisionInput {
  readonly redemptionId: string;
  readonly accountId: string;
  /** R en centavos. */
  readonly amountCents: number;
  /** S en centavos (para minimo 5R candidato). */
  readonly subtotalEligibleCents: number;
  readonly currency: 'MXN';
  /** Expiracion corta del instrumento. */
  readonly expiresAt: Date;
}

export interface ProvisionedDiscount {
  readonly discountId: string;
  readonly code: string;
}

export interface ShopifyDiscountAdapter {
  readonly name: string;
  readonly available: boolean;
  /** true solo si el mecanismo hace cumplir 20% + elegibilidad en el checkout definitivo. */
  readonly guaranteesLimitInCheckout: boolean;
  provision(input: DiscountProvisionInput): Promise<ProvisionedDiscount>;
  invalidate(discountId: string): Promise<void>;
  /** true no usado / false usado / null desconocido (conservar incertidumbre). */
  isUnused(discountId: string): Promise<boolean | null>;
}

export class DisabledDiscountAdapter implements ShopifyDiscountAdapter {
  readonly name = 'disabled';
  readonly available = false;
  readonly guaranteesLimitInCheckout = false;
  async provision(): Promise<ProvisionedDiscount> {
    throw Object.assign(new Error('redemption_disabled'), { code: 'redemption_disabled' });
  }
  async invalidate(): Promise<void> {}
  async isUnused(): Promise<boolean | null> { return null; }
}

export interface BasicCouponProvisioner {
  createSingleUseFixedCode(args: {
    amountCents: number; currency: 'MXN'; expiresAt: Date;
    customerId: string; redemptionId: string; minimumSubtotalCents: number | null;
  }): Promise<ProvisionedDiscount>;
  deleteCode(discountId: string): Promise<void>;
  /** Numero de usos registrados del codigo, o null si no se pudo verificar. */
  usageCount(discountId: string): Promise<number | null>;
}

/**
 * Cupon unico Basic: importe fijo R, un uso, cliente especifico, vencimiento
 * corto. NO garantiza el 20% ante edicion del carrito; exige reconciliacion.
 */
export class BasicSingleUseCouponAdapter implements ShopifyDiscountAdapter {
  readonly name = 'basic_single_use_coupon';
  readonly available = true;
  readonly guaranteesLimitInCheckout = false;
  constructor(private readonly provisioner: BasicCouponProvisioner) {}

  async provision(input: DiscountProvisionInput): Promise<ProvisionedDiscount> {
    // Candidato R con minimo 5R solo cuando el minimo corresponde a S.
    // Si S no es multiplo util, se provisiona sin minimo y la API ya limito R.
    const minimum = input.subtotalEligibleCents >= input.amountCents * 5
      ? input.subtotalEligibleCents
      : null;
    return this.provisioner.createSingleUseFixedCode({
      amountCents: input.amountCents,
      currency: input.currency,
      expiresAt: input.expiresAt,
      customerId: input.accountId,
      redemptionId: input.redemptionId,
      minimumSubtotalCents: minimum,
    });
  }

  async invalidate(discountId: string): Promise<void> {
    await this.provisioner.deleteCode(discountId);
  }

  async isUnused(discountId: string): Promise<boolean | null> {
    const count = await this.provisioner.usageCount(discountId);
    if (count === null) return null;
    return count === 0;
  }
}
