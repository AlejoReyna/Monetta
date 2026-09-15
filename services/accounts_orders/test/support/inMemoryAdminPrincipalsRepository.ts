import type { AdminPrincipalsRepository } from '../../src/admin/ports.js';
import type { AdminPrincipalRecord, AdminPrincipalSubject } from '../../src/admin/types.js';

export class InMemoryAdminPrincipalsRepository implements AdminPrincipalsRepository {
  readonly rows = new Map<string, AdminPrincipalRecord>();

  async findBySubject(subject: AdminPrincipalSubject): Promise<AdminPrincipalRecord | null> {
    return this.rows.get(`${subject.type}:${subject.id}`) ?? null;
  }

  async createIfAbsent(input: {
    readonly id: string;
    readonly subject: AdminPrincipalSubject;
    readonly role: 'owner';
    readonly createdBy: string;
  }): Promise<AdminPrincipalRecord> {
    const key = `${input.subject.type}:${input.subject.id}`;
    const existing = this.rows.get(key);
    if (existing !== undefined) return existing;
    const principal: AdminPrincipalRecord = {
      principalId: input.id,
      type: input.subject.type,
      id: input.subject.id,
      role: input.role,
      active: true,
      createdAt: new Date(),
      createdBy: input.createdBy,
      revokedAt: null,
    };
    this.rows.set(key, principal);
    return principal;
  }
}
