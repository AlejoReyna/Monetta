export interface AdminProductVariantProjection {
  readonly id: string;
  readonly title: string;
  readonly price: string;
  readonly compareAtPrice: string | null;
  readonly currencyCode?: string;
  readonly availableForSale: boolean;
  readonly inventoryPolicy: string;
}

export interface AdminProductProjection {
  readonly id: string;
  readonly title: string;
  readonly descriptionHtml?: string | null;
  readonly updatedAt: string;
  readonly status: string;
  readonly publishedOnPublication: boolean;
  readonly imageUrl?: string | null;
  readonly currencyCode?: string;
  readonly variants: readonly AdminProductVariantProjection[];
}

export interface AdminProductsPage {
  readonly currencyCode: string;
  readonly products: readonly AdminProductProjection[];
  readonly pageInfo: {
    readonly hasNextPage: boolean;
    readonly endCursor: string | null;
  };
}
