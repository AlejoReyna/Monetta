import { randomUUID } from 'node:crypto';
import type pg from 'pg';
import { RegistrationCipher } from '../crypto/registrationCipher.js';
import type { EngagementRepository } from '../domain/ports.js';
import type {
  CampaignInput,
  CampaignRecord,
  CampaignSummary,
  CatalogEventInput,
  ClaimedDelivery,
  ConsentPurpose,
  DeviceInstallation,
  EngagementOverview,
  InstallationRegistrationResult,
  InterestProfileInput,
  NotificationPreferencesInput,
  NotificationRoute,
  PushEndpointInput,
  RegisterInstallationInput,
  SegmentDefinition,
  SendResult,
} from '../domain/types.js';

interface CampaignRow {
  id: string;
  kind: CampaignRecord['kind'];
  purpose: CampaignRecord['purpose'];
  status: CampaignRecord['status'];
  title: string;
  body: string;
  image_url: string | null;
  route: NotificationRoute;
  segment_definition: SegmentDefinition;
  created_by: string;
  created_at: Date;
  scheduled_at: Date | null;
}

interface CampaignSummaryRow {
  id: string;
  kind: CampaignSummary['kind'];
  status: CampaignSummary['status'];
  title: string;
  scheduled_at: Date | null;
  created_at: Date;
  eligible_count: string | number;
  accepted_count: string | number;
  opened_count: string | number;
  failed_count: string | number;
}

export class PgEngagementRepository implements EngagementRepository {
  constructor(
    private readonly pool: pg.Pool,
    private readonly cipher: RegistrationCipher,
  ) {}

  async registerInstallation(input: RegisterInstallationInput): Promise<InstallationRegistrationResult> {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      const existing = await client.query<{ device_credential_hash: string }>(
        `SELECT device_credential_hash
           FROM device_installations
          WHERE device_id = $1
          FOR UPDATE`,
        [input.deviceId],
      );
      if (existing.rowCount === 0) {
        await client.query(
          `INSERT INTO device_installations
             (device_id, device_credential_hash, platform, locale, timezone, app_version,
              last_seen_at, created_at)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $7)`,
          [
            input.deviceId,
            input.credentialHash,
            input.platform,
            input.locale,
            input.timezone,
            input.appVersion,
            input.now,
          ],
        );
        await client.query(
          `INSERT INTO notification_preferences (device_id)
           VALUES ($1)
           ON CONFLICT (device_id) DO NOTHING`,
          [input.deviceId],
        );
        await client.query('COMMIT');
        return 'created';
      }

      if (
        input.existingCredentialHash === null ||
        input.existingCredentialHash !== existing.rows[0]!.device_credential_hash
      ) {
        await client.query('ROLLBACK');
        return 'conflict';
      }

      await client.query(
        `UPDATE device_installations
            SET device_credential_hash = $2,
                platform = $3,
                locale = $4,
                timezone = $5,
                app_version = $6,
                last_seen_at = $7,
                disabled_at = NULL
          WHERE device_id = $1`,
        [
          input.deviceId,
          input.credentialHash,
          input.platform,
          input.locale,
          input.timezone,
          input.appVersion,
          input.now,
        ],
      );
      await client.query('COMMIT');
      return 'refreshed';
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  async findInstallationByCredentialHash(credentialHash: string): Promise<DeviceInstallation | null> {
    const result = await this.pool.query<{
      device_id: string;
      platform: DeviceInstallation['platform'];
      locale: string;
      timezone: string;
      app_version: string;
      disabled_at: Date | null;
    }>(
      `SELECT device_id, platform, locale, timezone, app_version, disabled_at
         FROM device_installations
        WHERE device_credential_hash = $1`,
      [credentialHash],
    );
    const row = result.rows[0];
    return row === undefined
      ? null
      : {
          deviceId: row.device_id,
          platform: row.platform,
          locale: row.locale,
          timezone: row.timezone,
          appVersion: row.app_version,
          disabledAt: row.disabled_at,
        };
  }

  async upsertPushEndpoint(input: PushEndpointInput): Promise<void> {
    const ciphertext = this.cipher.encrypt(input.registrationId);
    const registrationHash = this.cipher.hash(input.registrationId);
    await this.pool.query(
      `INSERT INTO push_endpoints
         (id, device_id, registration_kind, registration_id_ciphertext,
          registration_id_hash, permission_state, status, token_updated_at, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6,
               CASE WHEN $6 = 'denied' THEN 'revoked' ELSE 'active' END, $7, $7)
       ON CONFLICT (device_id) DO UPDATE SET
         registration_kind = EXCLUDED.registration_kind,
         registration_id_ciphertext = EXCLUDED.registration_id_ciphertext,
         registration_id_hash = EXCLUDED.registration_id_hash,
         permission_state = EXCLUDED.permission_state,
         status = CASE WHEN EXCLUDED.permission_state = 'denied' THEN 'revoked' ELSE 'active' END,
         token_updated_at = EXCLUDED.token_updated_at,
         failure_count = 0,
         updated_at = EXCLUDED.updated_at`,
      [
        input.id,
        input.deviceId,
        input.registrationKind,
        ciphertext,
        registrationHash,
        input.permissionState,
        input.now,
      ],
    );
  }

  async updatePreferences(input: NotificationPreferencesInput): Promise<void> {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      await client.query(
        `INSERT INTO notification_preferences
           (device_id, product_alerts, personalized_offers, announcements,
            quiet_start, quiet_end, updated_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7)
         ON CONFLICT (device_id) DO UPDATE SET
           product_alerts = EXCLUDED.product_alerts,
           personalized_offers = EXCLUDED.personalized_offers,
           announcements = EXCLUDED.announcements,
           quiet_start = EXCLUDED.quiet_start,
           quiet_end = EXCLUDED.quiet_end,
           updated_at = EXCLUDED.updated_at`,
        [
          input.deviceId,
          input.productAlerts,
          input.personalizedOffers,
          input.announcements,
          input.quietStart,
          input.quietEnd,
          input.now,
        ],
      );
      for (const [purpose, granted] of [
        ['product_alerts', input.productAlerts],
        ['personalized_offers', input.personalizedOffers],
        ['announcements', input.announcements],
      ] as const) {
        await client.query(
          `INSERT INTO notification_consents
             (device_id, purpose, granted, policy_version, source, recorded_at)
           VALUES ($1, $2, $3, $4, $5, $6)
           ON CONFLICT (device_id, purpose) DO UPDATE SET
             granted = EXCLUDED.granted,
             policy_version = EXCLUDED.policy_version,
             source = EXCLUDED.source,
             recorded_at = EXCLUDED.recorded_at`,
          [input.deviceId, purpose, granted, input.policyVersion, input.source, input.now],
        );
      }
      await client.query('COMMIT');
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  async grantProductAlerts(deviceId: string, policyVersion: string, now: Date): Promise<void> {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      await client.query(
        `INSERT INTO notification_preferences (device_id, product_alerts, updated_at)
         VALUES ($1, TRUE, $2)
         ON CONFLICT (device_id) DO UPDATE SET
           product_alerts = TRUE,
           updated_at = EXCLUDED.updated_at`,
        [deviceId, now],
      );
      await client.query(
        `INSERT INTO notification_consents
           (device_id, purpose, granted, policy_version, source, recorded_at)
         VALUES ($1, 'product_alerts', TRUE, $2, 'product_alert', $3)
         ON CONFLICT (device_id, purpose) DO UPDATE SET
           granted = TRUE,
           policy_version = EXCLUDED.policy_version,
           source = EXCLUDED.source,
           recorded_at = EXCLUDED.recorded_at`,
        [deviceId, policyVersion, now],
      );
      await client.query('COMMIT');
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  async upsertInterestProfile(input: InterestProfileInput): Promise<boolean> {
    const result = await this.pool.query(
      `INSERT INTO device_interest_profiles
         (device_id, profile_version, top_brands, top_categories, price_band,
          intent_tier, signal_count_bucket, generated_at, expires_at, updated_at)
       VALUES ($1, $2, $3::jsonb, $4::jsonb, $5, $6, $7, $8, $9, now())
       ON CONFLICT (device_id) DO UPDATE SET
         profile_version = EXCLUDED.profile_version,
         top_brands = EXCLUDED.top_brands,
         top_categories = EXCLUDED.top_categories,
         price_band = EXCLUDED.price_band,
         intent_tier = EXCLUDED.intent_tier,
         signal_count_bucket = EXCLUDED.signal_count_bucket,
         generated_at = EXCLUDED.generated_at,
         expires_at = EXCLUDED.expires_at,
         updated_at = now()
       WHERE device_interest_profiles.profile_version < EXCLUDED.profile_version
       RETURNING device_id`,
      [
        input.deviceId,
        input.profileVersion,
        JSON.stringify(input.topBrands),
        JSON.stringify(input.topCategories),
        input.priceBand,
        input.intentTier,
        input.signalCountBucket,
        input.generatedAt,
        input.expiresAt,
      ],
    );
    return (result.rowCount ?? 0) > 0;
  }

  async upsertProductAlert(input: {
    id: string;
    deviceId: string;
    productKey: string;
    kind: 'restock' | 'price_drop';
    now: Date;
  }): Promise<string> {
    const result = await this.pool.query<{ id: string }>(
      `INSERT INTO product_alerts (id, device_id, product_key, kind, active, created_at, updated_at)
       VALUES ($1, $2, $3, $4, TRUE, $5, $5)
       ON CONFLICT (device_id, product_key, kind) DO UPDATE SET
         active = TRUE,
         updated_at = EXCLUDED.updated_at
       RETURNING id`,
      [input.id, input.deviceId, input.productKey, input.kind, input.now],
    );
    return result.rows[0]!.id;
  }

  async deleteProductAlert(deviceId: string, alertId: string): Promise<boolean> {
    const result = await this.pool.query(
      `UPDATE product_alerts SET active = FALSE, updated_at = now()
        WHERE id = $1 AND device_id = $2 AND active = TRUE`,
      [alertId, deviceId],
    );
    return (result.rowCount ?? 0) > 0;
  }

  async createCampaign(input: CampaignInput): Promise<CampaignRecord> {
    const result = await this.pool.query<CampaignRow>(
      `INSERT INTO notification_campaigns
         (id, kind, purpose, status, title, body, image_url, route,
          segment_definition, created_by, created_at)
       VALUES ($1, $2, $3, 'draft', $4, $5, $6, $7::jsonb, $8::jsonb, $9, $10)
       RETURNING *`,
      [
        input.id,
        input.kind,
        input.purpose,
        input.title,
        input.body,
        input.imageUrl,
        JSON.stringify(input.route),
        JSON.stringify(input.segment),
        input.createdBy,
        input.now,
      ],
    );
    await this.audit(input.createdBy, 'campaign.created', 'notification_campaign', input.id, {
      kind: input.kind,
      purpose: input.purpose,
    });
    return campaignFromRow(result.rows[0]!);
  }

  async getCampaign(id: string): Promise<CampaignRecord | null> {
    const result = await this.pool.query<CampaignRow>(
      'SELECT * FROM notification_campaigns WHERE id = $1',
      [id],
    );
    return result.rows[0] === undefined ? null : campaignFromRow(result.rows[0]);
  }

  async previewAudience(segment: SegmentDefinition, purpose: ConsentPurpose, now: Date): Promise<number> {
    const eligible = eligibilityQuery(segment, purpose, now, false);
    const result = await this.pool.query<{ count: string }>(
      `SELECT count(*)::text AS count FROM (${eligible.text}) audience`,
      eligible.values,
    );
    return Number.parseInt(result.rows[0]?.count ?? '0', 10);
  }

  async scheduleCampaign(id: string, scheduledAt: Date, actorId: string, now: Date): Promise<boolean> {
    const result = await this.pool.query(
      `UPDATE notification_campaigns
          SET status = 'scheduled', scheduled_at = $2, published_at = $3
        WHERE id = $1 AND status = 'draft'`,
      [id, scheduledAt, now],
    );
    if ((result.rowCount ?? 0) > 0) {
      await this.audit(actorId, 'campaign.scheduled', 'notification_campaign', id, {
        scheduledAt: scheduledAt.toISOString(),
      });
      return true;
    }
    return false;
  }

  async cancelCampaign(id: string, actorId: string, now: Date): Promise<boolean> {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      const result = await client.query(
        `UPDATE notification_campaigns
            SET status = 'cancelled', cancelled_at = $2
          WHERE id = $1 AND status IN ('draft', 'scheduled', 'targeting', 'sending')`,
        [id, now],
      );
      if ((result.rowCount ?? 0) > 0) {
        await client.query(
          `UPDATE notification_deliveries
              SET status = 'suppressed', provider_error_code = 'campaign_cancelled', updated_at = $2
            WHERE campaign_id = $1 AND status IN ('queued', 'retry')`,
          [id, now],
        );
        await client.query(
          `INSERT INTO admin_audit_events
             (actor_id, action, resource_type, resource_id, metadata)
           VALUES ($1, 'campaign.cancelled', 'notification_campaign', $2, '{}'::jsonb)`,
          [actorId, id],
        );
      }
      await client.query('COMMIT');
      return (result.rowCount ?? 0) > 0;
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  async getOverview(): Promise<EngagementOverview> {
    const [counts, campaigns] = await Promise.all([
      this.pool.query<{
        active_endpoints: string;
        granted_endpoints: string;
        personalized_profiles: string;
        queued_deliveries: string;
      }>(
        `SELECT
           (SELECT count(*) FROM push_endpoints WHERE status = 'active')::text AS active_endpoints,
           (SELECT count(*) FROM push_endpoints WHERE status = 'active' AND permission_state IN ('granted', 'provisional'))::text AS granted_endpoints,
           (SELECT count(*) FROM device_interest_profiles WHERE expires_at > now())::text AS personalized_profiles,
           (SELECT count(*) FROM notification_deliveries WHERE status IN ('queued', 'retry', 'sending'))::text AS queued_deliveries`,
      ),
      this.listRecentCampaigns(12),
    ]);
    const row = counts.rows[0]!;
    return {
      activeEndpoints: Number.parseInt(row.active_endpoints, 10),
      grantedEndpoints: Number.parseInt(row.granted_endpoints, 10),
      personalizedProfiles: Number.parseInt(row.personalized_profiles, 10),
      queuedDeliveries: Number.parseInt(row.queued_deliveries, 10),
      recentCampaigns: campaigns,
    };
  }

  async getCampaignReport(id: string): Promise<CampaignSummary | null> {
    const result = await this.pool.query<CampaignSummaryRow>(campaignSummarySql('WHERE c.id = $1'), [id]);
    return result.rows[0] === undefined ? null : campaignSummaryFromRow(result.rows[0]);
  }

  async materializeDueCampaigns(now: Date): Promise<number> {
    const client = await this.pool.connect();
    let materialized = 0;
    try {
      await client.query('BEGIN');
      const due = await client.query<CampaignRow>(
        `SELECT * FROM notification_campaigns
          WHERE status = 'scheduled' AND scheduled_at <= $1
          ORDER BY scheduled_at
          FOR UPDATE SKIP LOCKED`,
        [now],
      );
      for (const row of due.rows) {
        await client.query(
          `UPDATE notification_campaigns SET status = 'targeting' WHERE id = $1`,
          [row.id],
        );
        const eligible = eligibilityQuery(row.segment_definition, row.purpose, now, true);
        const endpoints = await client.query<{ endpoint_id: string }>(eligible.text, eligible.values);
        for (const endpoint of endpoints.rows) {
          await client.query(
            `INSERT INTO notification_deliveries
               (id, campaign_id, push_endpoint_id, eligibility_snapshot, status,
                next_attempt_at, created_at, updated_at)
             VALUES ($1, $2, $3, $4::jsonb, 'queued', $5, $5, $5)
             ON CONFLICT (campaign_id, push_endpoint_id) DO NOTHING`,
            [
              randomUUID(),
              row.id,
              endpoint.endpoint_id,
              JSON.stringify({ segment: row.segment_definition, evaluatedAt: now.toISOString() }),
              now,
            ],
          );
        }
        if (
          endpoints.rows.length > 0 &&
          row.segment_definition.kind === 'product_alert'
        ) {
          await client.query(
            `UPDATE product_alerts
                SET active = FALSE, updated_at = $4
              WHERE active = TRUE
                AND product_key = $1
                AND kind = $2
                AND device_id IN (
                  SELECT i.device_id
                    FROM push_endpoints e
                    JOIN device_installations i ON i.device_id = e.device_id
                   WHERE e.id = ANY($3::uuid[])
                )`,
            [
              row.segment_definition.value,
              row.segment_definition.alertKind,
              endpoints.rows.map((endpoint) => endpoint.endpoint_id),
              now,
            ],
          );
        }
        await client.query(
          `UPDATE notification_campaigns
              SET status = $2
            WHERE id = $1`,
          [row.id, endpoints.rowCount === 0 ? 'complete' : 'sending'],
        );
        materialized++;
      }
      await client.query('COMMIT');
      return materialized;
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  async claimDeliveries(now: Date, limit: number): Promise<readonly ClaimedDelivery[]> {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      const rows = await client.query<{
        id: string;
        campaign_id: string;
        registration_id_ciphertext: string;
        platform: ClaimedDelivery['platform'];
        title: string;
        body: string;
        image_url: string | null;
        route: NotificationRoute;
        kind: ClaimedDelivery['kind'];
        attempt_count: number;
      }>(
        `SELECT d.id, d.campaign_id, e.registration_id_ciphertext, i.platform,
                c.title, c.body, c.image_url, c.route, c.kind, d.attempt_count
           FROM notification_deliveries d
           JOIN notification_campaigns c ON c.id = d.campaign_id
           JOIN push_endpoints e ON e.id = d.push_endpoint_id
           JOIN device_installations i ON i.device_id = e.device_id
           JOIN notification_preferences pref ON pref.device_id = i.device_id
          WHERE d.status IN ('queued', 'retry')
            AND d.next_attempt_at <= $1
            AND c.status = 'sending'
            AND e.status = 'active'
            AND i.disabled_at IS NULL
            AND NOT (
              (
                pref.quiet_start < pref.quiet_end
                AND EXTRACT(HOUR FROM ($1 AT TIME ZONE i.timezone)) >= pref.quiet_start
                AND EXTRACT(HOUR FROM ($1 AT TIME ZONE i.timezone)) < pref.quiet_end
              )
              OR (
                pref.quiet_start > pref.quiet_end
                AND (
                  EXTRACT(HOUR FROM ($1 AT TIME ZONE i.timezone)) >= pref.quiet_start
                  OR EXTRACT(HOUR FROM ($1 AT TIME ZONE i.timezone)) < pref.quiet_end
                )
              )
            )
          ORDER BY d.next_attempt_at, d.created_at
          LIMIT $2
          FOR UPDATE OF d SKIP LOCKED`,
        [now, limit],
      );
      if (rows.rowCount !== 0) {
        await client.query(
          `UPDATE notification_deliveries
              SET status = 'sending', attempt_count = attempt_count + 1, updated_at = $2
            WHERE id = ANY($1::uuid[])`,
          [rows.rows.map((row) => row.id), now],
        );
      }
      await client.query('COMMIT');
      return rows.rows.map((row) => ({
        id: row.id,
        campaignId: row.campaign_id,
        registrationId: this.cipher.decrypt(row.registration_id_ciphertext),
        platform: row.platform,
        title: row.title,
        body: row.body,
        imageUrl: row.image_url,
        route: row.route,
        kind: row.kind,
        attemptCount: row.attempt_count + 1,
      }));
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  async markDeliveryResult(deliveryId: string, result: SendResult, now: Date): Promise<void> {
    const status = result.outcome === 'accepted'
      ? 'accepted'
      : result.outcome === 'invalid'
        ? 'invalid_token'
        : result.outcome === 'retryable'
          ? 'retry'
          : 'failed';
    const retryAt = result.retryAfter ?? new Date(now.getTime() + 60_000);
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      await client.query(
        `UPDATE notification_deliveries
            SET status = $2,
                next_attempt_at = CASE WHEN $2 = 'retry' THEN $3 ELSE next_attempt_at END,
                provider_message_id = $4,
                provider_error_code = $5,
                accepted_at = CASE WHEN $2 = 'accepted' THEN $6 ELSE accepted_at END,
                updated_at = $6
          WHERE id = $1`,
        [
          deliveryId,
          status,
          retryAt,
          result.providerMessageId ?? null,
          result.errorCode ?? null,
          now,
        ],
      );
      if (result.outcome === 'accepted') {
        await client.query(
          `UPDATE push_endpoints e
              SET last_success_at = $2, failure_count = 0, updated_at = $2
             FROM notification_deliveries d
            WHERE d.id = $1 AND e.id = d.push_endpoint_id`,
          [deliveryId, now],
        );
      } else if (result.outcome === 'invalid') {
        await client.query(
          `UPDATE push_endpoints e
              SET status = 'invalid', failure_count = failure_count + 1, updated_at = $2
             FROM notification_deliveries d
            WHERE d.id = $1 AND e.id = d.push_endpoint_id`,
          [deliveryId, now],
        );
      } else {
        await client.query(
          `UPDATE push_endpoints e
              SET failure_count = failure_count + 1, updated_at = $2
             FROM notification_deliveries d
            WHERE d.id = $1 AND e.id = d.push_endpoint_id`,
          [deliveryId, now],
        );
      }
      await client.query(
        `UPDATE notification_campaigns c
            SET status = 'complete'
          WHERE c.id = (SELECT campaign_id FROM notification_deliveries WHERE id = $1)
            AND NOT EXISTS (
              SELECT 1 FROM notification_deliveries d
               WHERE d.campaign_id = c.id AND d.status IN ('queued', 'retry', 'sending')
            )`,
        [deliveryId],
      );
      await client.query('COMMIT');
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  async recordInteraction(input: {
    deviceId: string;
    deliveryId: string;
    event: 'opened' | 'product_viewed' | 'add_to_cart' | 'checkout_started' | 'purchased';
    occurredAt: Date;
    idempotencyKey: string;
  }): Promise<boolean> {
    const result = await this.pool.query(
      `INSERT INTO notification_interactions
         (delivery_id, event, occurred_at, idempotency_key)
       SELECT $1, $2, $3, $4
         FROM notification_deliveries d
         JOIN push_endpoints e ON e.id = d.push_endpoint_id
        WHERE d.id = $1 AND e.device_id = $5
       ON CONFLICT DO NOTHING`,
      [input.deliveryId, input.event, input.occurredAt, input.idempotencyKey, input.deviceId],
    );
    return (result.rowCount ?? 0) > 0;
  }

  async recordCatalogEvent(event: CatalogEventInput): Promise<boolean> {
    const result = await this.pool.query(
      `INSERT INTO catalog_events
         (event_id, event_type, source, product_key, payload, occurred_at)
       VALUES ($1, $2, $3, $4, $5::jsonb, $6)
       ON CONFLICT (event_id) DO NOTHING`,
      [
        event.eventId,
        event.eventType,
        event.source,
        event.productKey,
        JSON.stringify({ before: event.before, after: event.after }),
        event.occurredAt,
      ],
    );
    return (result.rowCount ?? 0) > 0;
  }

  async isAutomationEnabled(key: string): Promise<boolean> {
    const result = await this.pool.query<{ enabled: boolean }>(
      'SELECT enabled FROM automation_rules WHERE key = $1',
      [key],
    );
    return result.rows[0]?.enabled === true;
  }

  async updateAutomationRule(
    key: string,
    enabled: boolean,
    configuration: Record<string, unknown>,
    actorId: string,
  ): Promise<void> {
    await this.pool.query(
      `INSERT INTO automation_rules (key, enabled, configuration, updated_by, updated_at)
       VALUES ($1, $2, $3::jsonb, $4, now())
       ON CONFLICT (key) DO UPDATE SET
         enabled = EXCLUDED.enabled,
         configuration = EXCLUDED.configuration,
         updated_by = EXCLUDED.updated_by,
         updated_at = now()`,
      [key, enabled, JSON.stringify(configuration), actorId],
    );
    await this.audit(actorId, 'automation.updated', 'automation_rule', key, { enabled });
  }

  async listAutomationRules(): Promise<readonly { key: string; enabled: boolean; configuration: Record<string, unknown> }[]> {
    const result = await this.pool.query<{
      key: string;
      enabled: boolean;
      configuration: Record<string, unknown>;
    }>('SELECT key, enabled, configuration FROM automation_rules ORDER BY key');
    return result.rows;
  }

  private async listRecentCampaigns(limit: number): Promise<readonly CampaignSummary[]> {
    const result = await this.pool.query<CampaignSummaryRow>(
      `${campaignSummarySql('')} ORDER BY c.created_at DESC LIMIT $1`,
      [limit],
    );
    return result.rows.map(campaignSummaryFromRow);
  }

  private async audit(
    actorId: string,
    action: string,
    resourceType: string,
    resourceId: string | null,
    metadata: Record<string, unknown>,
  ): Promise<void> {
    await this.pool.query(
      `INSERT INTO admin_audit_events
         (actor_id, action, resource_type, resource_id, metadata)
       VALUES ($1, $2, $3, $4, $5::jsonb)`,
      [actorId, action, resourceType, resourceId, JSON.stringify(metadata)],
    );
  }
}

function campaignFromRow(row: CampaignRow): CampaignRecord {
  return {
    id: row.id,
    kind: row.kind,
    purpose: row.purpose,
    status: row.status,
    title: row.title,
    body: row.body,
    imageUrl: row.image_url,
    route: row.route,
    segment: row.segment_definition,
    createdBy: row.created_by,
    now: row.created_at,
    scheduledAt: row.scheduled_at,
  };
}

function campaignSummarySql(where: string): string {
  return `SELECT c.id, c.kind, c.status, c.title, c.scheduled_at, c.created_at,
                 count(DISTINCT d.id)::text AS eligible_count,
                 count(DISTINCT d.id) FILTER (WHERE d.status = 'accepted')::text AS accepted_count,
                 count(DISTINCT i.delivery_id) FILTER (WHERE i.event = 'opened')::text AS opened_count,
                 count(DISTINCT d.id) FILTER (WHERE d.status IN ('failed', 'invalid_token'))::text AS failed_count
            FROM notification_campaigns c
            LEFT JOIN notification_deliveries d ON d.campaign_id = c.id
            LEFT JOIN notification_interactions i ON i.delivery_id = d.id
            ${where}
           GROUP BY c.id`;
}

function campaignSummaryFromRow(row: CampaignSummaryRow): CampaignSummary {
  return {
    id: row.id,
    kind: row.kind,
    status: row.status,
    title: row.title,
    scheduledAt: row.scheduled_at,
    createdAt: row.created_at,
    eligibleCount: Number(row.eligible_count),
    acceptedCount: Number(row.accepted_count),
    openedCount: Number(row.opened_count),
    failedCount: Number(row.failed_count),
  };
}

function eligibilityQuery(
  segment: SegmentDefinition,
  purpose: ConsentPurpose,
  now: Date,
  deduplicateAccounts: boolean,
): { text: string; values: unknown[] } {
  const values: unknown[] = [purpose, now];
  const conditions = [
    `e.status = 'active'`,
    `e.token_updated_at > $2 - interval '60 days'`,
    `e.permission_state IN ('granted', 'provisional')`,
    `i.disabled_at IS NULL`,
    `c.granted = TRUE`,
    preferenceCondition(purpose),
  ];
  const joins: string[] = [];

  switch (segment.kind) {
    case 'all':
      break;
    case 'brand': {
      values.push(segment.value, segment.minimumScore);
      conditions.push(
        `p.expires_at > $2`,
        `EXISTS (
           SELECT 1 FROM jsonb_array_elements(p.top_brands) affinity
            WHERE affinity->>'key' = $3
              AND (affinity->>'score')::int >= $4
         )`,
      );
      break;
    }
    case 'category': {
      values.push(segment.value, segment.minimumScore);
      conditions.push(
        `p.expires_at > $2`,
        `EXISTS (
           SELECT 1 FROM jsonb_array_elements(p.top_categories) affinity
            WHERE affinity->>'key' = $3
              AND (affinity->>'score')::int >= $4
         )`,
      );
      break;
    }
    case 'high_intent':
      conditions.push(`p.expires_at > $2`, `p.intent_tier = 'high'`);
      break;
    case 'product_alert':
      values.push(segment.value, segment.alertKind);
      joins.push(
        `JOIN product_alerts a
           ON a.device_id = i.device_id
          AND a.active = TRUE
          AND a.product_key = $3
          AND a.kind = $4`,
      );
      break;
    case 'device':
      values.push(segment.value);
      conditions.push(`i.device_id = $3`);
      break;
  }

  const selector = deduplicateAccounts
    ? `DISTINCT ON (COALESCE(i.app_account_id::text, 'device:' || i.device_id)) e.id AS endpoint_id`
    : `e.id AS endpoint_id`;
  const order = deduplicateAccounts
    ? `ORDER BY COALESCE(i.app_account_id::text, 'device:' || i.device_id), i.last_seen_at DESC`
    : '';

  return {
    text: `SELECT ${selector}
             FROM push_endpoints e
             JOIN device_installations i ON i.device_id = e.device_id
             JOIN notification_preferences pref ON pref.device_id = i.device_id
             JOIN notification_consents c ON c.device_id = i.device_id AND c.purpose = $1
             LEFT JOIN device_interest_profiles p ON p.device_id = i.device_id
             ${joins.join('\n')}
            WHERE ${conditions.join('\n AND ')}
              AND ($1 = 'product_alerts' OR NOT EXISTS (
                SELECT 1
                  FROM notification_deliveries recent
                  JOIN notification_campaigns recent_campaign ON recent_campaign.id = recent.campaign_id
                 WHERE recent.push_endpoint_id = e.id
                   AND recent.status = 'accepted'
                   AND recent_campaign.purpose <> 'product_alerts'
                   AND recent.accepted_at > $2 - interval '24 hours'
              ))
            ${order}`,
    values,
  };
}

function preferenceCondition(purpose: ConsentPurpose): string {
  switch (purpose) {
    case 'product_alerts':
      return 'pref.product_alerts = TRUE';
    case 'personalized_offers':
      return 'pref.personalized_offers = TRUE';
    case 'announcements':
      return 'pref.announcements = TRUE';
  }
}
