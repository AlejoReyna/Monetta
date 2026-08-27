/// GraphQL documents for the Storefront API.
///
/// Kept as Dart constants rather than `.graphql` files + codegen — see
/// `lib/data/shopify/README.md` § 3 for that decision.
///
/// Every document requests only the fields the app actually renders. On a
/// delta sync that runs on every app open, an over-fetched field is paid for
/// on every device, every session, forever.
library;

/// Fields shared by every product query. Kept in one fragment so the mapper
/// only ever has one shape to parse.
const String kProductFragment = r'''
fragment ProductFields on Product {
  id
  handle
  title
  vendor
  productType
  tags
  descriptionHtml
  createdAt
  updatedAt
  brandOverride: metafield(namespace: "app", key: "brand_override") { value }
  categoryOverride: metafield(namespace: "app", key: "category_override") { value }
  badge: metafield(namespace: "app", key: "badge") { value }
  images(first: 6) {
    edges { node { url(transform: {maxWidth: 1200}) } }
  }
  variants(first: 20) {
    edges {
      node {
        id
        title
        availableForSale
        price { amount currencyCode }
        compareAtPrice { amount }
        sku
      }
    }
  }
  collections(first: 10) { edges { node { handle } } }
}
''';

/// The navigation menu. This is what makes the app's category nav
/// owner-controlled: edit Shopify → Navigation and the app follows.
const String kMenuQuery = r'''
query Menu($handle: String!) {
  menu(handle: $handle) {
    id
    title
    items {
      title
      url
      type
      resource { ... on Collection { handle } ... on Product { handle } }
      items {
        title
        url
        type
        resource { ... on Collection { handle } ... on Product { handle } }
      }
    }
  }
}
''';

/// All collections, with product counts so empty ones can be hidden.
///
/// 7 of the store's 21 collections currently have zero products; rendering them
/// would give the user dead ends.
const String kCollectionsQuery = r'''
query Collections($first: Int!, $after: String) {
  collections(first: $first, after: $after, sortKey: TITLE) {
    pageInfo { hasNextPage endCursor }
    edges {
      node {
        id
        handle
        title
        description
        image { url(transform: {maxWidth: 800}) }
        products(first: 1) { pageInfo { hasNextPage } }
      }
    }
  }
}
''';

/// **The delta sync query — the mechanism behind "the owner adds products with
/// no help from us".**
///
/// `$query` carries a Shopify search filter such as `updated_at:>2026-08-05T07:24:40Z`.
/// The supported filter fields on this connection are `available_for_sale`,
/// `created_at`, `product_type`, `tag`, `tag_not`, `title`, `updated_at`,
/// `variants.price` and `vendor`.
///
/// On a typical open this returns zero products and costs a few hundred bytes.
const String kProductsDeltaQuery = '''
$kProductFragment
query ProductsDelta(\$first: Int!, \$after: String, \$query: String) {
  products(first: \$first, after: \$after, query: \$query, sortKey: UPDATED_AT) {
    pageInfo { hasNextPage endCursor }
    edges { node { ...ProductFields } }
  }
}
''';

/// Products within a collection, for the browse screens.
const String kCollectionProductsQuery = '''
$kProductFragment
query CollectionProducts(
  \$handle: String!
  \$first: Int!
  \$after: String
  \$sortKey: ProductCollectionSortKeys
  \$reverse: Boolean
) {
  collection(handle: \$handle) {
    id
    handle
    title
    products(first: \$first, after: \$after, sortKey: \$sortKey, reverse: \$reverse) {
      pageInfo { hasNextPage endCursor }
      edges { node { ...ProductFields } }
    }
  }
}
''';

const String kProductByHandleQuery = '''
$kProductFragment
query ProductByHandle(\$handle: String!) {
  product(handle: \$handle) { ...ProductFields }
}
''';

/// Shopify's own related-products engine, blended with our on-device score on
/// the product detail page.
const String kProductRecommendationsQuery = '''
$kProductFragment
query ProductRecommendations(\$productId: ID!) {
  productRecommendations(productId: \$productId, intent: RELATED) {
    ...ProductFields
  }
}
''';

/// Type-ahead search. Cheaper and better ranked than a full `products(query:)`
/// call, and it also returns matching collections.
const String kPredictiveSearchQuery = r'''
query PredictiveSearch($query: String!, $limit: Int!) {
  predictiveSearch(query: $query, limit: $limit, types: [PRODUCT, COLLECTION]) {
    products {
      id
      handle
      title
      vendor
      featuredImage { url(transform: {maxWidth: 400}) }
      priceRange { minVariantPrice { amount currencyCode } }
    }
    collections { id handle title }
  }
}
''';

/// Optional owner-editable content for the two non-commerce experiences.
///
/// The app ships a complete offline fallback, so missing Metaobject
/// definitions are harmless. To enable overrides, expose these definitions to
/// the Storefront API:
/// - `app_about` / handle `monetta`
/// - `app_partner_program` / handle `vende-con-monetta`
/// - any number of `reseller_catalog` entries
const String kEditorialContentQuery = r'''
query AppEditorialContent {
  about: metaobject(handle: {type: "app_about", handle: "monetta"}) {
    fields { key value }
  }
  partner: metaobject(
    handle: {type: "app_partner_program", handle: "vende-con-monetta"}
  ) {
    fields { key value }
  }
  catalogs: metaobjects(type: "reseller_catalog", first: 50) {
    edges {
      node {
        handle
        fields { key value }
      }
    }
  }
}
''';

const String kCartFragment = r'''
fragment CartFields on Cart {
  id
  checkoutUrl
  totalQuantity
  cost { subtotalAmount { amount currencyCode } }
  lines(first: 50) {
    edges {
      node {
        id
        quantity
        cost { amountPerQuantity { amount } }
        merchandise {
          ... on ProductVariant {
            id
            title
            image { url(transform: {maxWidth: 400}) }
            product { id title handle }
          }
        }
      }
    }
  }
}
''';

/// Creates the cart. `$attributes` carries the attribution payload that makes
/// the revenue-share arrangement auditable — see `cart_attribution.dart`.
const String kCartCreateMutation = '''
$kCartFragment
mutation CartCreate(\$lines: [CartLineInput!], \$attributes: [AttributeInput!]) {
  cartCreate(input: {lines: \$lines, attributes: \$attributes}) {
    cart { ...CartFields }
    userErrors { field message }
  }
}
''';

const String kCartLinesAddMutation = '''
$kCartFragment
mutation CartLinesAdd(\$cartId: ID!, \$lines: [CartLineInput!]!) {
  cartLinesAdd(cartId: \$cartId, lines: \$lines) {
    cart { ...CartFields }
    userErrors { field message }
  }
}
''';

const String kCartLinesUpdateMutation = '''
$kCartFragment
mutation CartLinesUpdate(\$cartId: ID!, \$lines: [CartLineUpdateInput!]!) {
  cartLinesUpdate(cartId: \$cartId, lines: \$lines) {
    cart { ...CartFields }
    userErrors { field message }
  }
}
''';

const String kCartLinesRemoveMutation = '''
$kCartFragment
mutation CartLinesRemove(\$cartId: ID!, \$lineIds: [ID!]!) {
  cartLinesRemove(cartId: \$cartId, lineIds: \$lineIds) {
    cart { ...CartFields }
    userErrors { field message }
  }
}
''';

const String kCartQuery = '''
$kCartFragment
query Cart(\$cartId: ID!) {
  cart(id: \$cartId) { ...CartFields }
}
''';

/// Shop-level metafields driving the home screen layout, so the owner can
/// reorder home sections from Shopify → Settings → Metafields.
const String kShopConfigQuery = r'''
query ShopConfig {
  shop {
    name
    homeSections: metafield(namespace: "app", key: "home_sections") { value }
    announcement: metafield(namespace: "app", key: "announcement") { value }
  }
}
''';

/// Home composition and image sources. The collection connection is queried
/// alongside shop metafields so one Storefront request refreshes the surface.
const String kHomeContentQuery = r'''
query HomeContent {
  shop {
    homeSections: metafield(namespace: "app", key: "home_sections") { value }
    homeCollections: metafield(namespace: "app", key: "home_collections") { value }
    homeBagTypes: metafield(namespace: "app", key: "home_bag_types") { value }
    socialLinks: metafield(namespace: "app", key: "social_links") { value }
    aboutImageUrl: metafield(namespace: "app", key: "about_image_url") { value }
  }
  collections(first: 50, sortKey: TITLE) {
    edges {
      node {
        id
        handle
        title
        description
        image { url(transform: {maxWidth: 1200}) }
        products(first: 1) { pageInfo { hasNextPage } edges { node { id } } }
      }
    }
  }
}
''';
