import { createHash, randomUUID } from 'node:crypto';
import type { AppAccountsRepository } from '../domain/ports.js';
import type { CustomerTokenVerifier } from '../auth/customerTokenVerifier.js';
import type { AdminPrincipalsRepository } from './ports.js';
import type { ShopifySessionTokenVerifier } from './shopifySessionToken.js';
import type {
  AdminActor,
  AdminAuthentication,
  AdminCapabilities,
  AdminPrincipalSubject,
} from './types.js';

export interface AdminAuthorizer {
  /** Resolves any authenticated subject, including a non-admin shopper. */
  resolve(bearerToken: string): Promise<AdminAuthentication | null>;

  /**
   * Resolves only an active owner whose credential may open the full control
   * plane. A Shopify Admin staff session never qualifies; it is scoped to
   * notifications and is checked through `resolve` capabilities instead.
   */
  authenticate(bearerToken: string): Promise<AdminActor | null>;
}

export class AdminAuthenticationUnavailableError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'AdminAuthenticationUnavailableError';
  }
}

export const noAdminCapabilities: AdminCapabilities = {
  openAdmin: false,
  manageFeaturedCatalog: false,
  manageProducts: false,
  manageStorefront: false,
  manageNotifications: false,
};

export const ownerAdminCapabilities: AdminCapabilities = {
  openAdmin: true,
  manageFeaturedCatalog: true,
  manageProducts: true,
  manageStorefront: true,
  manageNotifications: true,
};

/**
 * What an owner can do from the embedded Shopify Admin panel. That page only
 * sends notifications, so its session token grants nothing else.
 */
export const notificationAdminCapabilities: AdminCapabilities = {
  ...noAdminCapabilities,
  manageNotifications: true,
};

export function hashAdminBearerToken(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}

/**
 * Authorizes admin access from durable principals. Monetta first-party emails
 * are self-declared and never bootstrap owner privileges. Shopify Customer
 * Account tokens may bootstrap from an explicit server allow-list of customer
 * ids (a verified identity), and Shopify Admin session tokens from an allow-list
 * of staff ids. Operators may also provision principals through the
 * reviewable provisionOwners CLI — never by matching an unverified email.
 */
export class ServerAdminAuthorizer implements AdminAuthorizer {
  constructor({
    appAccounts,
    customerTokenVerifier,
    principals,
    ownerShopifyCustomerIds,
    shopifySessionTokens,
    ownerShopifyStaffIds = new Set(),
  }: {
    readonly appAccounts: AppAccountsRepository;
    readonly customerTokenVerifier: CustomerTokenVerifier;
    readonly principals: AdminPrincipalsRepository;
    readonly ownerShopifyCustomerIds: ReadonlySet<string>;
    /** Absent until the Shopify app's client id, secret and shop are configured. */
    readonly shopifySessionTokens?: ShopifySessionTokenVerifier;
    readonly ownerShopifyStaffIds?: ReadonlySet<string>;
  }) {
    this.appAccounts = appAccounts;
    this.customerTokenVerifier = customerTokenVerifier;
    this.principals = principals;
    this.ownerShopifyCustomerIds = ownerShopifyCustomerIds;
    this.shopifySessionTokens = shopifySessionTokens;
    this.ownerShopifyStaffIds = ownerShopifyStaffIds;
  }

  private readonly appAccounts: AppAccountsRepository;
  private readonly customerTokenVerifier: CustomerTokenVerifier;
  private readonly principals: AdminPrincipalsRepository;
  private readonly ownerShopifyCustomerIds: ReadonlySet<string>;
  private readonly shopifySessionTokens: ShopifySessionTokenVerifier | undefined;
  private readonly ownerShopifyStaffIds: ReadonlySet<string>;

  async resolve(bearerToken: string): Promise<AdminAuthentication | null> {
    // Checked first: it is a local signature check, and a session token would
    // otherwise cost a database lookup and a Customer Account API round trip.
    const staff = this.shopifySessionTokens?.verify(bearerToken) ?? null;
    if (staff !== null) {
      return this.resolveSubject(
        { type: 'shopify_staff', id: staff.staffUserId },
        'shopify_admin',
        this.ownerShopifyStaffIds.has(staff.staffUserId),
      );
    }

    const appAccount = await this.appAccounts.findByTokenHash(
      hashAdminBearerToken(bearerToken),
    );
    if (appAccount !== null) {
      // First-party emails are unverified profile metadata. Never bootstrap
      // owner from OWNER_ADMIN_EMAILS or any self-declared address.
      return this.resolveSubject(
        {
          type: 'app_account',
          id: appAccount.id,
        },
        'monetta',
        false,
      );
    }

    let customerId: string | null;
    try {
      customerId = canonicalShopifyCustomerId(
        await this.customerTokenVerifier.resolveCustomerId(bearerToken),
      );
    } catch (error) {
      throw new AdminAuthenticationUnavailableError(
        error instanceof Error ? error.message : 'Customer authentication failed',
      );
    }
    if (customerId === null) return null;

    return this.resolveSubject(
      { type: 'shopify_customer', id: customerId },
      'shopify',
      this.ownerShopifyCustomerIds.has(customerId),
    );
  }

  async authenticate(bearerToken: string): Promise<AdminActor | null> {
    const authentication = await this.resolve(bearerToken);
    return authentication?.actor.role === 'owner' && authentication.capabilities.openAdmin
      ? authentication.actor
      : null;
  }

  private async resolveSubject(
    subject: AdminPrincipalSubject,
    provider: AdminActor['provider'],
    bootstrapOwner: boolean,
  ): Promise<AdminAuthentication> {
    let principal = await this.principals.findBySubject(subject);
    // A configured bootstrap may create a missing principal, but it must never
    // revive a principal that an operator explicitly deactivated.
    if (principal === null && bootstrapOwner) {
      principal = await this.principals.createIfAbsent({
        id: randomUUID(),
        subject,
        role: 'owner',
        createdBy: 'bootstrap:server-config',
      });
    }

    const activeOwner = principal?.active === true && principal.role === 'owner';
    const actor: AdminActor = {
      id: principal?.principalId ?? `${subject.type}:${subject.id}`,
      provider,
      subject,
      role: activeOwner ? 'owner' : null,
    };
    return {
      actor,
      capabilities: !activeOwner
        ? noAdminCapabilities
        : subject.type === 'shopify_staff'
          ? notificationAdminCapabilities
          : ownerAdminCapabilities,
    };
  }
}

export function canonicalShopifyCustomerId(value: string | null): string | null {
  if (value === null) return null;
  if (/^[0-9]+$/.test(value)) return value;
  const gid = /^gid:\/\/shopify\/Customer\/([0-9]+)$/.exec(value);
  return gid?.[1] ?? null;
}
