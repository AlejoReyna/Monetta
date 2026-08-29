import type { MessagingProvider } from '../domain/ports.js';
import type { OutboundMessage, SendResult } from '../domain/types.js';
import { GoogleAccessTokenProvider } from './googleAccessTokenProvider.js';

export class FcmMessagingProvider implements MessagingProvider {
  constructor(
    private readonly projectId: string,
    private readonly tokens: GoogleAccessTokenProvider,
    private readonly fetchFn: typeof fetch = fetch,
  ) {}

  async validate(message: OutboundMessage): Promise<void> {
    validateMessage(message);
  }

  async send(registrationId: string, message: OutboundMessage): Promise<SendResult> {
    validateMessage(message);
    const token = await this.tokens.accessToken();
    const response = await this.fetchFn(
      `https://fcm.googleapis.com/v1/projects/${encodeURIComponent(this.projectId)}/messages:send`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          message: {
            token: registrationId,
            notification: {
              title: message.title,
              body: message.body,
              ...(message.imageUrl === null ? {} : { image: message.imageUrl }),
            },
            data: {
              schemaVersion: '1',
              deliveryId: message.deliveryId,
              campaignId: message.campaignId,
              source: message.source,
              route: JSON.stringify(message.route),
            },
            android: {
              priority: 'high',
              notification: { channel_id: 'monetta_remote' },
            },
            apns: {
              headers: { 'apns-priority': '10' },
              payload: { aps: { sound: 'default' } },
            },
          },
        }),
        signal: AbortSignal.timeout(15_000),
      },
    );

    const json = await safeJson(response);
    if (response.ok) {
      return {
        outcome: 'accepted',
        providerMessageId: typeof json?.name === 'string' ? json.name : undefined,
      };
    }

    const code = providerErrorCode(json) ?? `http_${response.status}`;
    if (code.includes('UNREGISTERED') || code.includes('INVALID_ARGUMENT')) {
      return { outcome: 'invalid', errorCode: code };
    }
    if (response.status === 429 || response.status >= 500) {
      return {
        outcome: 'retryable',
        errorCode: code,
        retryAfter: parseRetryAfter(response.headers.get('retry-after')),
      };
    }
    return { outcome: 'failed', errorCode: code };
  }
}

function validateMessage(message: OutboundMessage): void {
  if (message.title.trim() === '' || message.title.length > 80) throw new Error('invalid push title');
  if (message.body.trim() === '' || message.body.length > 180) throw new Error('invalid push body');
  if (message.imageUrl !== null) {
    const image = new URL(message.imageUrl);
    if (image.protocol !== 'https:') throw new Error('push image must use HTTPS');
  }
}

async function safeJson(response: Response): Promise<Record<string, unknown> | null> {
  try {
    const value = await response.json();
    return value !== null && typeof value === 'object' && !Array.isArray(value)
      ? value as Record<string, unknown>
      : null;
  } catch {
    return null;
  }
}

function providerErrorCode(json: Record<string, unknown> | null): string | null {
  const error = json?.error;
  if (error === null || typeof error !== 'object' || Array.isArray(error)) return null;
  const record = error as Record<string, unknown>;
  const details = Array.isArray(record.details) ? record.details : [];
  for (const detail of details) {
    if (detail !== null && typeof detail === 'object' && !Array.isArray(detail)) {
      const code = (detail as Record<string, unknown>).errorCode;
      if (typeof code === 'string') return code;
    }
  }
  return typeof record.status === 'string' ? record.status : null;
}

function parseRetryAfter(value: string | null): Date | undefined {
  if (value === null) return undefined;
  const seconds = Number.parseInt(value, 10);
  if (Number.isFinite(seconds)) return new Date(Date.now() + seconds * 1000);
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? undefined : date;
}
