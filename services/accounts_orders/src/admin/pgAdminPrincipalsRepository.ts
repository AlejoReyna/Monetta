import type pg from 'pg';
import type { AdminPrincipalsRepository } from './ports.js';
import type { AdminPrincipalRecord, AdminPrincipalSubject } from './types.js';

interface AdminPrincipalRow {
  id: string;
  subject_type: AdminPrincipalSubject['type'];
  subject_id: string;
  role: 'owner';
  active: boolean;
  created_at: Date;
  created_by: string;
  revoked_at: Date | null;
}

function fromRow(row: AdminPrincipalRow): AdminPrincipalRecord {
  return {
    principalId: row.id,
    type: row.subject_type,
    id: row.subject_id,
    role: row.role,
    active: row.active,
    createdAt: row.created_at,
    createdBy: row.created_by,
    revokedAt: row.revoked_at,
  };
}

export class PgAdminPrincipalsRepository implements AdminPrincipalsRepository {
  constructor(private readonly pool: pg.Pool) {}

  async findBySubject(subject: AdminPrincipalSubject): Promise<AdminPrincipalRecord | null> {
    const result = await this.pool.query<AdminPrincipalRow>(
      `SELECT id, subject_type, subject_id, role, active,
              created_at, created_by, revoked_at
         FROM admin_principals
        WHERE subject_type = $1 AND subject_id = $2 AND role = 'owner'`,
      [subject.type, subject.id],
    );
    const row = result.rows[0];
    return row === undefined ? null : fromRow(row);
  }

  async createIfAbsent(input: {
    readonly id: string;
    readonly subject: AdminPrincipalSubject;
    readonly role: 'owner';
    readonly createdBy: string;
  }): Promise<AdminPrincipalRecord> {
    await this.pool.query(
      `INSERT INTO admin_principals
         (id, subject_type, subject_id, role, active, created_by)
       VALUES ($1, $2, $3, $4, TRUE, $5)
       ON CONFLICT (subject_type, subject_id, role) DO NOTHING`,
      [input.id, input.subject.type, input.subject.id, input.role, input.createdBy],
    );
    const principal = await this.findBySubject(input.subject);
    if (principal === null) throw new Error('admin principal was not created');
    return principal;
  }
}
