import type { AppDataEraser, AppDataErasureResult } from './ports.js';

const documentCollections = ['profiles', 'wishlists', 'savedRecommendations'] as const;
const subcollections = ['profile', 'wishlist', 'savedRecommendations'] as const;

/**
 * Deletes the Firebase Auth user and the Firestore profile, wishlist, and
 * saved-recommendation documents for one Shopify customer. Documents are
 * addressed by the numeric customer id. A missing user or document is success.
 */
export class FirebaseAppDataEraser implements AppDataEraser {
  constructor(private readonly options: {
    readonly projectId: string;
    readonly accessToken: () => Promise<string>;
    readonly fetchFn?: typeof fetch;
    readonly timeoutMs?: number;
  }) {}

  async erase(shopifyCustomerId: string): Promise<AppDataErasureResult> {
    if (!/^[0-9]+$/.test(shopifyCustomerId)) {
      throw new Error('invalid_customer_id');
    }
    const token = await this.options.accessToken();
    const projectId = this.options.projectId.trim();
    if (projectId === '' || !/^[a-z0-9-]{4,60}$/.test(projectId)) {
      throw new Error('firebase_not_configured');
    }

    const profile = await this.readProfile(token, projectId, shopifyCustomerId);
    const firebaseUid = profile.firebaseUid;
    const auth = firebaseUid === null
      ? 'absent' as const
      : await this.deleteAuthUser(token, projectId, firebaseUid);

    const profileResult = await this.deleteDocument(
      token,
      projectId,
      `customers/${shopifyCustomerId}`,
    );
    const wishlist = await this.deleteSubcollection(token, projectId, shopifyCustomerId, 'wishlist');
    const savedRecommendations = await this.deleteSubcollection(
      token,
      projectId,
      shopifyCustomerId,
      'savedRecommendations',
    );
    for (const collection of documentCollections) {
      await this.deleteDocument(token, projectId, `${collection}/${shopifyCustomerId}`);
    }
    for (const collection of subcollections) {
      if (collection === 'wishlist' || collection === 'savedRecommendations') continue;
      await this.deleteSubcollection(token, projectId, shopifyCustomerId, collection);
    }

    return {
      firebaseAuth: auth,
      profile: profile.existed ? 'deleted' : profileResult,
      wishlist,
      savedRecommendations,
      firebaseUid,
    };
  }

  private async readProfile(
    token: string,
    projectId: string,
    customerId: string,
  ): Promise<{ readonly existed: boolean; readonly firebaseUid: string | null }> {
    const response = await this.request(
      token,
      'GET',
      `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/customers/${customerId}`,
    );
    if (response.status === 404) return { existed: false, firebaseUid: null };
    if (!response.ok) throw new Error('firestore_read_failed');
    const body = await response.json() as { readonly fields?: Record<string, { readonly stringValue?: unknown }> };
    const fields = body.fields ?? {};
    const uid = stringField(fields.firebaseUid) ?? stringField(fields.uid) ?? stringField(fields.authUid);
    return { existed: true, firebaseUid: uid };
  }

  private async deleteAuthUser(
    token: string,
    projectId: string,
    uid: string,
  ): Promise<'deleted' | 'absent'> {
    const response = await this.request(
      token,
      'POST',
      `https://identitytoolkit.googleapis.com/v1/projects/${projectId}/accounts:delete`,
      { localId: uid },
    );
    if (response.ok) return 'deleted';
    const body = await response.text();
    if (response.status === 400 && body.includes('USER_NOT_FOUND')) return 'absent';
    throw new Error('firebase_auth_delete_failed');
  }

  private async deleteSubcollection(
    token: string,
    projectId: string,
    customerId: string,
    collection: string,
  ): Promise<'deleted' | 'absent'> {
    let pageToken = '';
    let deleted = false;
    for (;;) {
      const query = pageToken === '' ? '' : `?pageToken=${encodeURIComponent(pageToken)}`;
      const response = await this.request(
        token,
        'GET',
        `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/customers/${customerId}/${collection}${query}`,
      );
      if (response.status === 404) return deleted ? 'deleted' : 'absent';
      if (!response.ok) throw new Error('firestore_list_failed');
      const body = await response.json() as {
        readonly documents?: readonly { readonly name?: unknown }[];
        readonly nextPageToken?: unknown;
      };
      const documents = body.documents ?? [];
      if (documents.length === 0 && pageToken === '') return deleted ? 'deleted' : 'absent';
      for (const document of documents) {
        if (typeof document.name !== 'string') continue;
        const deletedResponse = await this.request(
          token,
          'DELETE',
          `https://firestore.googleapis.com/v1/${document.name}`,
        );
        if (!deletedResponse.ok && deletedResponse.status !== 404) {
          throw new Error('firestore_delete_failed');
        }
        deleted = true;
      }
      pageToken = typeof body.nextPageToken === 'string' ? body.nextPageToken : '';
      if (pageToken === '') return deleted ? 'deleted' : 'absent';
    }
  }

  private async deleteDocument(
    token: string,
    projectId: string,
    path: string,
  ): Promise<'deleted' | 'absent'> {
    const response = await this.request(
      token,
      'DELETE',
      `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/${path}`,
    );
    if (response.status === 404) return 'absent';
    if (!response.ok) throw new Error('firestore_delete_failed');
    return 'deleted';
  }

  private async request(
    token: string,
    method: string,
    url: string,
    body?: unknown,
  ): Promise<Response> {
    const fetchFn = this.options.fetchFn ?? fetch;
    try {
      return await fetchFn(url, {
        method,
        headers: {
          Authorization: `Bearer ${token}`,
          Accept: 'application/json',
          ...(body === undefined ? {} : { 'Content-Type': 'application/json' }),
        },
        ...(body === undefined ? {} : { body: JSON.stringify(body) }),
        signal: AbortSignal.timeout(this.options.timeoutMs ?? 10_000),
      });
    } catch {
      throw new Error('firebase_request_failed');
    }
  }
}

function stringField(field: { readonly stringValue?: unknown } | undefined): string | null {
  const value = field?.stringValue;
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  if (!/^[A-Za-z0-9]{1,128}$/.test(trimmed)) return null;
  return trimmed;
}
