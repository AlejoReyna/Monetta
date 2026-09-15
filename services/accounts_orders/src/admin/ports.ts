import type { AdminPrincipalRecord, AdminPrincipalSubject } from './types.js';

export interface AdminPrincipalsRepository {
  /** Reads a principal even when inactive, so revocation cannot be bypassed by bootstrap config. */
  findBySubject(subject: AdminPrincipalSubject): Promise<AdminPrincipalRecord | null>;

  /** Creates a configured bootstrap principal without reactivating an existing one. */
  createIfAbsent(input: {
    readonly id: string;
    readonly subject: AdminPrincipalSubject;
    readonly role: 'owner';
    readonly createdBy: string;
  }): Promise<AdminPrincipalRecord>;
}
