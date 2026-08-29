import { describe, expect, it } from 'vitest';
import {
  CustomerTokenVerificationUnavailableError,
  ShopifyCustomerTokenVerifier,
} from '../src/auth/customerTokenVerifier.js';

const discoveryUrl = 'https://shop.example.com/.well-known/customer-account-api';
const graphQlUrl = 'https://accounts.example.com/customer/api/2026-07/graphql';

describe('ShopifyCustomerTokenVerifier', () => {
  it('discovers once and resolves the customer using the raw access token', async () => {
    const requests: Array<{ url: string; authorization: string | null; userAgent: string | null }> = [];
    const fetchFn: typeof fetch = async (input, init) => {
      const url = input.toString();
      const headers = new Headers(init?.headers);
      requests.push({
        url,
        authorization: headers.get('Authorization'),
        userAgent: headers.get('User-Agent'),
      });
      if (url === discoveryUrl) {
        return new Response(JSON.stringify({ graphql_api: graphQlUrl }), {
          status: 200,
          headers: { 'Content-Type': 'application/json' },
        });
      }
      return new Response(
        JSON.stringify({ data: { customer: { id: 'gid://shopify/Customer/77' } } }),
        { status: 200, headers: { 'Content-Type': 'application/json' } },
      );
    };
    const verifier = new ShopifyCustomerTokenVerifier({
      shopDomain: 'shop.example.com',
      fetchFn,
    });

    expect(await verifier.resolveCustomerId('access-one')).toBe(
      'gid://shopify/Customer/77',
    );
    expect(await verifier.resolveCustomerId('access-two')).toBe(
      'gid://shopify/Customer/77',
    );

    expect(requests.filter((request) => request.url === discoveryUrl)).toHaveLength(1);
    expect(requests.filter((request) => request.url === graphQlUrl)).toHaveLength(2);
    expect(requests[1]).toMatchObject({
      authorization: 'access-one',
      userAgent: 'MonettaAccountsOrders/0.1 (+https://monetta.mx)',
    });
  });

  it('returns null for a token Shopify rejects', async () => {
    const fetchFn: typeof fetch = async (input) =>
      input.toString() === discoveryUrl
        ? new Response(JSON.stringify({ graphql_api: graphQlUrl }), { status: 200 })
        : new Response('', { status: 401 });
    const verifier = new ShopifyCustomerTokenVerifier({
      shopDomain: 'shop.example.com',
      fetchFn,
    });

    expect(await verifier.resolveCustomerId('invalid-access')).toBeNull();
  });

  it('fails closed when discovery is missing or unsafe', async () => {
    const missingEndpoint = new ShopifyCustomerTokenVerifier({
      shopDomain: 'shop.example.com',
      fetchFn: async () => new Response('{}', { status: 200 }),
    });
    const unsafeEndpoint = new ShopifyCustomerTokenVerifier({
      shopDomain: 'shop.example.com',
      fetchFn: async () =>
        new Response(JSON.stringify({ graphql_api: 'https://127.0.0.1/graphql' }), {
          status: 200,
        }),
    });

    await expect(missingEndpoint.resolveCustomerId('access')).rejects.toBeInstanceOf(
      CustomerTokenVerificationUnavailableError,
    );
    await expect(unsafeEndpoint.resolveCustomerId('access')).rejects.toBeInstanceOf(
      CustomerTokenVerificationUnavailableError,
    );
  });

  it('treats non-authentication GraphQL errors as an unavailable verifier', async () => {
    const fetchFn: typeof fetch = async (input) =>
      input.toString() === discoveryUrl
        ? new Response(JSON.stringify({ graphql_api: graphQlUrl }), { status: 200 })
        : new Response(JSON.stringify({ errors: [{ message: 'Internal failure' }] }), {
            status: 200,
          });
    const verifier = new ShopifyCustomerTokenVerifier({
      shopDomain: 'shop.example.com',
      fetchFn,
    });

    await expect(verifier.resolveCustomerId('access')).rejects.toBeInstanceOf(
      CustomerTokenVerificationUnavailableError,
    );
  });
});
