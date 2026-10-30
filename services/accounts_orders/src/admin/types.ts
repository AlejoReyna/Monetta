/**
 * `shopify_staff` is a Shopify Admin user, identified by the session token of
 * the embedded panel. That channel is scoped to notifications (see
 * `authorizer.ts`), so such a principal never reaches the full control plane.
 */
export type AdminPrincipalSubjectType = 'app_account' | 'shopify_customer' | 'shopify_staff';

export interface AdminPrincipalSubject {
  readonly type: AdminPrincipalSubjectType;
  readonly id: string;
}

export interface AdminPrincipalRecord extends AdminPrincipalSubject {
  readonly principalId: string;
  readonly role: 'owner';
  readonly active: boolean;
  readonly createdAt: Date;
  readonly createdBy: string;
  readonly revokedAt: Date | null;
}

export type AdminProvider = 'monetta' | 'shopify' | 'shopify_admin';

export interface AdminActor {
  readonly id: string;
  readonly provider: AdminProvider;
  readonly subject: AdminPrincipalSubject;
  readonly role: 'owner' | null;
}

export interface AdminCapabilities {
  readonly openAdmin: boolean;
  readonly manageFeaturedCatalog: boolean;
  readonly manageProducts: boolean;
  readonly manageStorefront: boolean;
  readonly manageNotifications: boolean;
}

export interface AdminAuthentication {
  readonly actor: AdminActor;
  readonly capabilities: AdminCapabilities;
}
