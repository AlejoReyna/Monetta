export type AdminPrincipalSubjectType = 'app_account' | 'shopify_customer';

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

export type AdminProvider = 'monetta' | 'shopify';

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
  readonly manageExternalSources: boolean;
  readonly manageNotifications: boolean;
}

export interface AdminAuthentication {
  readonly actor: AdminActor;
  readonly capabilities: AdminCapabilities;
}
