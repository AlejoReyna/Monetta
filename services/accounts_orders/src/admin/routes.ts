import { createHash, randomUUID } from 'node:crypto';
import type { Express, NextFunction, Request, Response } from 'express';
import {
  AdminAuthenticationUnavailableError,
  type AdminAuthorizer,
} from './authorizer.js';
import {
  ShopifyAdminError,
  ShopifyAdminUserError,
  type ShopifyAdminReadClient,
  type ShopifyAdminWriteClient,
} from './shopifyAdminClient.js';
import type { AdminProductProjection } from './shopifyTypes.js';
import type {
  AdminFeaturedCatalogProjection,
  AdminFeaturedCollectionProjection,
} from './featuredTypes.js';
import type { AdminFeaturedJobRepository } from './featuredPorts.js';
import type { AdminStorefrontConfigProjection } from './storefrontTypes.js';
import type {
  AdminAuditLogger,
  AdminAuditReader,
  AdminIdempotencyRepository,
  AdminMutationRateLimiter,
} from './mutationPorts.js';
import type {
  ExternalCatalogAdminClient,
  ExternalSourcePolicyInput,
  ExternalSourceProjection,
} from './externalCatalogClient.js';
import type {
  AdminSyncChannel,
  AdminSyncJobRecord,
  AdminSyncJobRepository,
} from './syncPorts.js';
import type { PrivacyRequestsRepository } from '../domain/ports.js';

export interface AdminRouteDeps {
  readonly authorizer: AdminAuthorizer;
  readonly environment: 'staging' | 'production';
  readonly shopify?: ShopifyAdminReadClient;
  readonly shopifyWrites?: ShopifyAdminWriteClient;
  readonly idempotency?: AdminIdempotencyRepository;
  readonly audit?: AdminAuditLogger;
  readonly auditReader?: AdminAuditReader;
  readonly rateLimiter?: AdminMutationRateLimiter;
  readonly mutationsEnabled?: boolean;
  readonly shopifyWritesEnabled?: boolean;
  readonly featuredJobs?: AdminFeaturedJobRepository;
  readonly externalCatalog?: ExternalCatalogAdminClient;
  readonly now?: () => Date;
  readonly externalWritesEnabled?: boolean;
  readonly syncJobs?: AdminSyncJobRepository;
  readonly privacyRequests?: PrivacyRequestsRepository;
}

export function registerAdminRoutes(app: Express, deps: AdminRouteDeps): void {
  app.get('/admin/me', asyncRoute(async (req, res) => {
    const token = bearerCredential(req);
    if (token === null) {
      adminError(res, 401, 'UNAUTHORIZED', 'A valid session is required.');
      return;
    }

    let authentication;
    try {
      authentication = await deps.authorizer.resolve(token);
    } catch (error) {
      if (error instanceof AdminAuthenticationUnavailableError) {
        adminError(res, 503, 'AUTHENTICATION_UNAVAILABLE', 'Authentication is temporarily unavailable.');
        return;
      }
      throw error;
    }
    if (authentication === null) {
      adminError(res, 401, 'UNAUTHORIZED', 'The session is invalid or expired.');
      return;
    }

    res.status(200).json({
      actor: {
        id: authentication.actor.id,
        provider: authentication.actor.provider,
      },
      roles: authentication.actor.role === null ? [] : [authentication.actor.role],
      capabilities: authentication.capabilities,
      environment: deps.environment,
    });
  }));

  app.get('/admin/audit', asyncRoute(async (req, res) => {
    const owner = await requireOwner(req, res, deps.authorizer);
    if (owner === null) return;
    const reader = auditReaderFor(deps);
    if (reader === null) {
      adminError(res, 503, 'AUDIT_NOT_CONFIGURED', 'Audit history is not configured.');
      return;
    }
    const beforeId = decodeAuditCursor(nullableQueryString(req.query.cursor));
    if (beforeId === undefined) {
      adminError(res, 400, 'INVALID_CURSOR', 'The audit cursor is invalid.');
      return;
    }
    try {
      const records = await reader.list({
        beforeId,
        limit: Math.min(boundedLimit(req.query.limit), 50),
      });
      res.status(200).json({
        requestId: requestIdFor(res),
        events: records.map(auditJson),
        nextCursor: records.length === Math.min(boundedLimit(req.query.limit), 50)
          ? encodeAuditCursor(records[records.length - 1]?.id ?? 0)
          : null,
      });
    } catch (_) {
      adminError(res, 503, 'AUDIT_UNAVAILABLE', 'Audit history is temporarily unavailable.');
    }
  }));

  app.post('/admin/sync', asyncRoute(async (req, res) => {
    const owner = await requireOwner(req, res, deps.authorizer);
    if (owner === null) return;
    const channel = syncChannelValue(plainObject(req.body ?? {})?.channel);
    if (channel === null) {
      adminError(res, 422, 'INVALID_SYNC_CHANNEL', 'A supported sync channel is required.');
      return;
    }
    const jobs = deps.syncJobs;
    const idempotency = deps.idempotency;
    if (jobs === undefined || idempotency === undefined) {
      adminError(res, 503, 'SYNC_NOT_CONFIGURED', 'Sync jobs are not configured.');
      return;
    }
    const idempotencyKey = req.header('Idempotency-Key')?.trim() ?? '';
    if (idempotencyKey === '' || idempotencyKey.length > 200 || /\s/.test(idempotencyKey)) {
      adminError(res, 400, 'IDEMPOTENCY_KEY_REQUIRED', 'Every sync request requires an Idempotency-Key.');
      return;
    }
    const operation = `sync.${channel}`;
    const requestId = requestIdFor(res);
    const body = { channel };
    const claim = await idempotency.claim({
      actorId: owner.id,
      idempotencyKey,
      operation,
      bodyHash: hashJson(body),
      requestId,
      expiresAt: new Date((deps.now ?? (() => new Date()))().getTime() + 24 * 60 * 60 * 1_000),
    });
    if (claim.outcome === 'conflict') {
      adminError(res, 409, 'IDEMPOTENCY_CONFLICT', 'The idempotency key was already used for another request.');
      return;
    }
    if (claim.outcome === 'replay') {
      res.status(claim.record.statusCode ?? 500).json(claim.record.responseBody);
      return;
    }
    const job = await jobs.create({ id: randomUUID(), actorId: owner.id, channel });
    const responseBody = {
      requestId,
      job: syncJobJson(job),
    };
    await idempotency.complete({
      actorId: owner.id,
      idempotencyKey,
      statusCode: 202,
      responseBody,
    });
    if (deps.audit !== undefined) {
      await deps.audit.record({
        actor: owner,
        requestId,
        action: operation,
        targetType: 'admin_sync_job',
        targetId: job.id,
        outcome: 'success',
      });
    }
    res.status(202).json(responseBody);
    void runSyncJob({ deps, owner, jobId: job.id, channel });
  }));

  app.get('/admin/sync/jobs/:jobId', asyncRoute(async (req, res) => {
    const owner = await requireOwner(req, res, deps.authorizer);
    if (owner === null) return;
    const jobId = typeof req.params.jobId === 'string' ? req.params.jobId : '';
    if (!/^[0-9a-f-]{36}$/i.test(jobId) || deps.syncJobs === undefined) {
      adminError(res, 404, 'SYNC_JOB_NOT_FOUND', 'The sync job was not found.');
      return;
    }
    let job = await deps.syncJobs.find(jobId);
    if (job === null || job.actorId !== owner.id) {
      adminError(res, 404, 'SYNC_JOB_NOT_FOUND', 'The sync job was not found.');
      return;
    }
    // Resume interrupted work when the process lost the in-memory runner.
    if (job.status === 'pending' || job.status === 'running') {
      void runSyncJob({ deps, owner, jobId: job.id, channel: job.channel });
      job = (await deps.syncJobs.find(jobId)) ?? job;
    }
    res.status(200).json({ requestId: requestIdFor(res), job: syncJobJson(job) });
  }));

  app.get('/admin/control-plane', asyncRoute(async (req, res) => {
    const owner = await requireOwner(req, res, deps.authorizer);
    if (owner === null) return;

    const fetchedAt = (deps.now ?? (() => new Date()))().toISOString();
    const limit = boundedLimit(req.query.limit);
    const cursor = nullableQueryString(req.query.cursor);
    const searchQuery = nullableQueryString(req.query.q);
    let products: readonly AdminProductProjection[] = [];
    let pageInfo = { hasNextPage: false, endCursor: null as string | null };
    let productsTotal: number | null = null;
    let shopifyStatus: 'ready' | 'degraded' | 'unavailable' = 'unavailable';
    let shopifyErrorCode: string | null = null;
    let featuredStatus: 'ready' | 'degraded' | 'unavailable' = 'unavailable';
    let featuredErrorCode: string | null = 'FEATURED_COLLECTION_NOT_CONFIGURED';
    let storefront: AdminStorefrontConfigProjection | null = null;
    let storefrontStatus: 'ready' | 'degraded' | 'unavailable' = 'unavailable';
    let storefrontErrorCode: string | null = 'STOREFRONT_CONFIG_NOT_CONFIGURED';
    let sourceRows: readonly ExternalSourceProjection[] = [];
    let sourcesStatus: 'ready' | 'degraded' | 'unavailable' = 'unavailable';
    let sourcesErrorCode: string | null = 'EXTERNAL_CATALOG_NOT_CONFIGURED';
    if (deps.shopify === undefined) {
      shopifyErrorCode = 'SHOPIFY_NOT_CONFIGURED';
    } else {
      try {
        const page = await deps.shopify.listProducts({
          first: limit,
          after: cursor,
          query: searchQuery,
        });
        products = page.products;
        pageInfo = page.pageInfo;
        if ('countProducts' in deps.shopify && typeof deps.shopify.countProducts === 'function') {
          productsTotal = await deps.shopify.countProducts({ query: searchQuery });
        }
        shopifyStatus = 'ready';
      } catch (error) {
        shopifyStatus = 'degraded';
        shopifyErrorCode = shopifyErrorCodeFor(error);
      }
    }
    const featured = featuredClient(deps);
    if (featured !== null) {
      try {
        await featured.getFeaturedCollection();
        featuredStatus = 'ready';
        featuredErrorCode = null;
      } catch (error) {
        featuredStatus = error instanceof ShopifyAdminError && error.code === 'not_configured'
          ? 'unavailable'
          : 'degraded';
        featuredErrorCode = featuredErrorCodeFor(error);
      }
    }
    const storefrontAdmin = storefrontClient(deps);
    if (storefrontAdmin !== null) {
      try {
        storefront = await storefrontAdmin.getStorefrontConfig();
        storefrontStatus = storefront === null ? 'degraded' : 'ready';
        storefrontErrorCode = storefront === null ? 'STOREFRONT_CONFIG_MISSING' : null;
      } catch (error) {
        storefrontStatus = 'degraded';
        storefrontErrorCode = shopifyErrorCodeFor(error);
      }
    }
    if (deps.externalCatalog !== undefined) {
      try {
        sourceRows = await deps.externalCatalog.fetchSources(requestIdFor(res));
        sourcesStatus = 'ready';
        sourcesErrorCode = null;
      } catch (error) {
        sourcesStatus = 'degraded';
        sourcesErrorCode = errorCodeForExternal(error);
      }
    }

    const productRows = products.map(productJson);
    const auditStatus = auditReaderFor(deps) === null ? 'unavailable' : 'ready';
    res.status(200).json({
      requestId: res.locals.requestId,
      fetchedAt,
      health: {
        shopify: {
          status: shopifyStatus,
          fetchedAt: shopifyStatus === 'ready' ? fetchedAt : null,
          errorCode: shopifyErrorCode,
        },
        storefront: {
          status: storefrontStatus,
          fetchedAt: storefrontStatus === 'ready' ? fetchedAt : null,
          errorCode: storefrontErrorCode,
        },
        sources: {
          status: sourcesStatus,
          fetchedAt: sourcesStatus === 'ready' ? fetchedAt : null,
          errorCode: sourcesErrorCode,
        },
        audit: {
          status: auditStatus,
          fetchedAt: auditStatus === 'ready' ? fetchedAt : null,
          errorCode: auditStatus === 'ready' ? null : 'AUDIT_NOT_CONFIGURED',
        },
        featured: {
          status: featuredStatus,
          fetchedAt: featuredStatus === 'ready' ? fetchedAt : null,
          errorCode: featuredErrorCode,
        },
      },
      // Keep the top-level projection compatible with the existing Flutter
      // client while the later work packages add the typed nested sections.
      products: productRows,
      pageInfo,
      productsMeta: {
        loadedCount: productRows.length,
        hasNextPage: pageInfo.hasNextPage,
        endCursor: pageInfo.endCursor,
        totalCount: productsTotal,
        query: searchQuery,
        limit,
      },
      storefront: storefront === null ? null : storefrontJson(storefront),
      sources: sourceRows,
    });
  }));

  app.get('/admin/products', asyncRoute(async (req, res) => {
    const owner = await requireOwner(req, res, deps.authorizer);
    if (owner === null) return;
    if (deps.shopify === undefined) {
      adminError(res, 503, 'SHOPIFY_NOT_CONFIGURED', 'Shopify is not configured.');
      return;
    }
    const limit = boundedLimit(req.query.limit);
    const cursor = nullableQueryString(req.query.cursor);
    const searchQuery = nullableQueryString(req.query.q);
    try {
      const page = await deps.shopify.listProducts({
        first: limit,
        after: cursor,
        query: searchQuery,
      });
      let totalCount: number | null = null;
      if ('countProducts' in deps.shopify && typeof deps.shopify.countProducts === 'function') {
        totalCount = await deps.shopify.countProducts({ query: searchQuery });
      }
      res.status(200).json({
        requestId: requestIdFor(res),
        products: page.products.map(productJson),
        pageInfo: page.pageInfo,
        productsMeta: {
          loadedCount: page.products.length,
          hasNextPage: page.pageInfo.hasNextPage,
          endCursor: page.pageInfo.endCursor,
          totalCount,
          query: searchQuery,
          limit,
        },
      });
    } catch (error) {
      adminError(res, 503, shopifyErrorCodeFor(error), 'Shopify product listing is temporarily unavailable.');
    }
  }));

  app.patch('/admin/products/:productGid', asyncRoute(async (req, res) => {
    const owner = await requireOwner(req, res, deps.authorizer);
    if (owner === null) return;
    const productGid = productGidValue(req.params.productGid);
    const body = plainObject(req.body) ?? {};
    const title = stringValue(body.title, 255);
    const expectedUpdatedAt = instantValue(body.expectedUpdatedAt);
    if (productGid === null || title === null || expectedUpdatedAt === null) {
      adminError(res, 422, 'VALIDATION_ERROR', 'Product id, title, and expectedUpdatedAt are required.');
      return;
    }
    await runProductMutation({
      req,
      res,
      deps,
      owner,
      operation: 'product.title.update',
      targetId: productGid,
      body: { productGid, title, expectedUpdatedAt: expectedUpdatedAt.toISOString() },
      work: async (client) => {
        const current = await currentProduct(client, productGid);
        assertFresh(current, expectedUpdatedAt);
        if (current.title !== title) await client.updateProductTitle(productGid, title);
        return canonicalProduct(client, productGid);
      },
    });
  }));

  app.patch('/admin/products/:productGid/variants/:variantGid', asyncRoute(async (req, res) => {
    const owner = await requireOwner(req, res, deps.authorizer);
    if (owner === null) return;
    const productGid = productGidValue(req.params.productGid);
    const variantGid = variantGidValue(req.params.variantGid);
    const body = plainObject(req.body) ?? {};
    const price = moneyValue(body.price);
    const expectedProductUpdatedAt = instantValue(body.expectedProductUpdatedAt);
    if (
      productGid === null || variantGid === null || price === null ||
      expectedProductUpdatedAt === null
    ) {
      adminError(res, 422, 'VALIDATION_ERROR', 'Product, variant, price, and expectedProductUpdatedAt are required.');
      return;
    }
    await runProductMutation({
      req,
      res,
      deps,
      owner,
      operation: 'product.variant-price.update',
      targetId: `${productGid}/${variantGid}`,
      body: {
        productGid,
        variantGid,
        price,
        expectedProductUpdatedAt: expectedProductUpdatedAt.toISOString(),
      },
      work: async (client) => {
        const current = await currentProduct(client, productGid);
        assertFresh(current, expectedProductUpdatedAt);
        const variant = current.variants.find((item) => item.id === variantGid);
        if (variant === undefined) {
          throw new AdminRouteError(422, 'VARIANT_NOT_FOUND', 'The selected variant was not found.');
        }
        if (variant.price !== price) {
          await client.updateVariantPrice(productGid, variantGid, price);
        }
        return canonicalProduct(client, productGid);
      },
    });
  }));

  app.put('/admin/products/:productGid/publication', asyncRoute(async (req, res) => {
    const owner = await requireOwner(req, res, deps.authorizer);
    if (owner === null) return;
    const productGid = productGidValue(req.params.productGid);
    const body = plainObject(req.body) ?? {};
    const published = booleanValue(body.published);
    const expectedUpdatedAt = instantValue(body.expectedUpdatedAt);
    if (productGid === null || published === null || expectedUpdatedAt === null) {
      adminError(res, 422, 'VALIDATION_ERROR', 'Product id, published, and expectedUpdatedAt are required.');
      return;
    }
    await runProductMutation({
      req,
      res,
      deps,
      owner,
      operation: 'product.publication.update',
      targetId: productGid,
      body: { productGid, published, expectedUpdatedAt: expectedUpdatedAt.toISOString() },
      work: async (client) => {
        const current = await currentProduct(client, productGid);
        assertFresh(current, expectedUpdatedAt);
        if (current.publishedOnPublication !== published) {
          await client.setPublication(productGid, published);
        }
        return canonicalProduct(client, productGid);
      },
    });
  }));

  app.put('/admin/storefront-config', asyncRoute(async (req, res) => {
    const owner = await requireOwner(req, res, deps.authorizer);
    if (owner === null) return;
    const body = plainObject(req.body) ?? {};
    const announcement = textValue(body.announcement, 70);
    const showHero = booleanValue(body.showHero);
    const showNewest = booleanValue(body.showNewest);
    const showTodaysPicks = booleanValue(body.showTodaysPicks);
    const showExternalPicks = booleanValue(body.showExternalPicks);
    const expectedVersion = integerValue(body.expectedVersion);
    if (
      announcement === null || showHero === null || showNewest === null ||
      showTodaysPicks === null || showExternalPicks === null || expectedVersion === null
    ) {
      adminError(res, 422, 'VALIDATION_ERROR', 'All storefront fields and expectedVersion are required.');
      return;
    }
    const client = storefrontClient(deps);
    if (client === null) {
      adminError(res, 503, 'STOREFRONT_NOT_CONFIGURED', 'Storefront configuration is not available.');
      return;
    }
    await runStorefrontMutation({
      req,
      res,
      deps,
      owner,
      body: { announcement, showHero, showNewest, showTodaysPicks, showExternalPicks, expectedVersion },
      expectedVersion,
      client,
    });
  }));

  app.get('/admin/external-policy/:sourceId', asyncRoute(async (req, res) => {
    const owner = await requireOwner(req, res, deps.authorizer);
    if (owner === null) return;
    const sourceId = externalSourceIdValue(req.params.sourceId);
    if (sourceId === null || deps.externalCatalog === undefined) {
      adminError(res, 404, 'EXTERNAL_SOURCE_NOT_FOUND', 'The external source was not found.');
      return;
    }
    try {
      const source = await deps.externalCatalog.fetchSource(sourceId, requestIdFor(res));
      res.status(200).json({ requestId: requestIdFor(res), source });
    } catch (error) {
      const mapped = mapExternalError(error);
      adminError(res, mapped.status, mapped.code, mapped.message);
    }
  }));

  app.put('/admin/external-policy/:sourceId', asyncRoute(async (req, res) => {
    const owner = await requireOwner(req, res, deps.authorizer);
    if (owner === null) return;
    const sourceId = externalSourceIdValue(req.params.sourceId);
    const body = plainObject(req.body) ?? {};
    const policy = externalPolicyValue(body);
    if (sourceId === null || policy === null) {
      adminError(res, 422, 'VALIDATION_ERROR', 'A valid bounded external policy is required.');
      return;
    }
    const client = deps.externalCatalog;
    if (client === undefined) {
      adminError(res, 503, 'EXTERNAL_CATALOG_NOT_CONFIGURED', 'The external catalog is not configured.');
      return;
    }
    await runExternalPolicyMutation({
      req,
      res,
      deps,
      owner,
      sourceId,
      body: { sourceId, ...policy },
      client,
      policy,
    });
  }));

  app.get('/admin/featured-catalog', asyncRoute(async (req, res) => {
    const owner = await requireOwner(req, res, deps.authorizer);
    if (owner === null) return;
    const client = featuredClient(deps);
    if (client === null) {
      adminError(res, 503, 'FEATURED_COLLECTION_NOT_CONFIGURED', 'Today\'s Picks is not configured.');
      return;
    }
    try {
      const projection = await readFeaturedCatalog(client);
      res.status(200).json({
        requestId: requestIdFor(res),
        limits: { min: 0, max: 12 },
        health: { status: 'ready', errorCode: null },
        featuredCatalog: featuredCatalogJson(projection),
      });
    } catch (error) {
      const mapped = mapFeaturedError(error);
      res.status(mapped.status).json({
        error: {
          code: mapped.code,
          message: mapped.message,
          fields: mapped.fields,
          requestId: requestIdFor(res),
        },
      });
    }
  }));

  app.put('/admin/featured-catalog', asyncRoute(async (req, res) => {
    const owner = await requireOwner(req, res, deps.authorizer);
    if (owner === null) return;
    const body = plainObject(req.body) ?? {};
    const productIds = productIdsValue(body.productIds);
    const expectedCollectionUpdatedAt = instantValue(body.expectedCollectionUpdatedAt);
    if (productIds === null || expectedCollectionUpdatedAt === null) {
      adminError(res, 422, 'VALIDATION_ERROR', 'productIds and expectedCollectionUpdatedAt are required.');
      return;
    }
    await runFeaturedMutation({
      req,
      res,
      deps,
      owner,
      operation: 'featured-catalog.replace',
      targetId: 'monetta-todays-picks',
      body: {
        productIds,
        expectedCollectionUpdatedAt: expectedCollectionUpdatedAt.toISOString(),
      },
      desiredProductIds: productIds,
      expectedCollectionUpdatedAt,
    });
  }));

  app.put('/admin/featured-catalog/products/:productGid', asyncRoute(async (req, res) => {
    const owner = await requireOwner(req, res, deps.authorizer);
    if (owner === null) return;
    const productGid = productGidValue(req.params.productGid);
    const body = plainObject(req.body) ?? {};
    const featured = booleanValue(body.featured);
    const expectedCollectionUpdatedAt = instantValue(body.expectedCollectionUpdatedAt);
    if (productGid === null || featured === null || expectedCollectionUpdatedAt === null) {
      adminError(res, 422, 'VALIDATION_ERROR', 'Product id, featured, and expectedCollectionUpdatedAt are required.');
      return;
    }
    const client = featuredClient(deps);
    if (client === null) {
      adminError(res, 503, 'FEATURED_COLLECTION_NOT_CONFIGURED', 'Today\'s Picks is not configured.');
      return;
    }
    let collection: AdminFeaturedCollectionProjection;
    try {
      collection = await requiredFeaturedCollection(client);
      assertCollectionFresh(collection, expectedCollectionUpdatedAt);
    } catch (error) {
      const mapped = mapFeaturedError(error);
      featuredError(res, mapped);
      return;
    }
    const current = [...collection.productIds];
    const isSelected = current.includes(productGid);
    const desired = featured
      ? isSelected ? current : [...current, productGid]
      : current.filter((id) => id !== productGid);
    if (desired.length > 12) {
      adminError(res, 422, 'FEATURED_LIMIT_REACHED', 'Today\'s Picks can contain at most 12 products.');
      return;
    }
    await runFeaturedMutation({
      req,
      res,
      deps,
      owner,
      operation: featured ? 'featured-catalog.add' : 'featured-catalog.remove',
      targetId: productGid,
      body: {
        productGid,
        featured,
        expectedCollectionUpdatedAt: expectedCollectionUpdatedAt.toISOString(),
      },
      desiredProductIds: desired,
      expectedCollectionUpdatedAt,
      currentCollection: collection,
    });
  }));

  app.get('/admin/featured-catalog/jobs/:jobId', asyncRoute(async (req, res) => {
    const owner = await requireOwner(req, res, deps.authorizer);
    if (owner === null) return;
    const rawJobId = req.params.jobId;
    const jobId = typeof rawJobId === 'string' ? rawJobId : '';
    if (!/^[0-9a-f-]{36}$/i.test(jobId)) {
      adminError(res, 404, 'JOB_NOT_FOUND', 'The reorder job was not found.');
      return;
    }
    const featuredJobs = deps.featuredJobs;
    if (featuredJobs === undefined) {
      adminError(res, 503, 'FEATURED_JOBS_NOT_CONFIGURED', 'Featured reorder jobs are not configured.');
      return;
    }
    const job = await featuredJobs.find(jobId);
    if (job === null || job === undefined || job.actorId !== owner.id) {
      adminError(res, 404, 'JOB_NOT_FOUND', 'The reorder job was not found.');
      return;
    }
    const client = featuredClient(deps);
    if (client === null) {
      adminError(res, 503, 'FEATURED_COLLECTION_NOT_CONFIGURED', 'Today\'s Picks is not configured.');
      return;
    }
    let status = job.status;
    let errorCode = job.errorCode;
    if (status === 'pending') {
      try {
        const upstream = await client.getJob(job.shopifyJobId);
        if (upstream.done) {
          const projection = await readFeaturedCatalog(client);
          const actual = projection.collection?.productIds ?? [];
          status = arraysEqual(actual, job.requestedProductIds) ? 'completed' : 'degraded';
          errorCode = status === 'completed' ? null : 'FEATURED_RECONCILIATION_MISMATCH';
          await featuredJobs.update({ jobId, status, errorCode });
          if (deps.audit !== undefined) {
            await deps.audit.record({
              actor: owner,
              requestId: requestIdFor(res),
              action: 'featured-catalog.reorder.reconcile',
              targetType: 'shopify_collection',
              targetId: job.collectionId,
              outcome: status === 'completed' ? 'success' : 'failed',
              ...(errorCode === null ? {} : { errorCode }),
            });
          }
        }
      } catch (error) {
        status = 'degraded';
        errorCode = featuredErrorCodeFor(error);
        await featuredJobs.update({ jobId, status, errorCode });
      }
    }
    res.status(200).json({
      requestId: requestIdFor(res),
      job: { id: jobId, status, errorCode },
    });
  }));

  app.get('/admin/privacy-requests', asyncRoute(async (req, res) => {
    const owner = await requireOwner(req, res, deps.authorizer);
    if (owner === null) return;
    if (!deps.privacyRequests) {
      adminError(res, 503, 'PRIVACY_TRACKING_UNAVAILABLE', 'Privacy request tracking is not configured.');
      return;
    }
    const open = await deps.privacyRequests.listOpen();
    res.status(200).json({
      requests: open.map((row) => ({
        webhookId: row.webhookId,
        shopifyCustomerId: row.shopifyCustomerId,
        kind: row.kind,
        status: row.status,
        receivedAt: row.receivedAt.toISOString(),
        notes: row.notes,
        exportArtifactRef: row.exportArtifactRef,
        operator: row.operator,
      })),
    });
  }));

  app.post('/admin/privacy-requests/:webhookId/fulfill', asyncRoute(async (req, res) => {
    const owner = await requireOwner(req, res, deps.authorizer);
    if (owner === null) return;
    if (!deps.privacyRequests) {
      adminError(res, 503, 'PRIVACY_TRACKING_UNAVAILABLE', 'Privacy request tracking is not configured.');
      return;
    }
    const webhookId = String(req.params.webhookId ?? '');
    if (!webhookId) {
      adminError(res, 400, 'INVALID_REQUEST', 'webhookId is required.');
      return;
    }
    const body = req.body !== null && typeof req.body === 'object' && !Array.isArray(req.body)
      ? req.body as Record<string, unknown>
      : {};
    const notes = typeof body.notes === 'string' ? body.notes.slice(0, 2000) : null;
    const exportArtifactRef = typeof body.exportArtifactRef === 'string'
      ? body.exportArtifactRef.slice(0, 500)
      : null;
    const ok = await deps.privacyRequests.markFulfilled({
      webhookId,
      operator: owner.id,
      notes,
      exportArtifactRef,
    });
    if (!ok) {
      adminError(res, 404, 'PRIVACY_REQUEST_NOT_OPEN', 'No open privacy request for that webhook id.');
      return;
    }
    if (deps.audit !== undefined) {
      await deps.audit.record({
        actor: owner,
        requestId: requestIdFor(res),
        action: 'privacy.request.fulfill',
        targetType: 'privacy_request',
        targetId: webhookId,
        outcome: 'success',
      });
    }
    res.status(200).json({ status: 'fulfilled', webhookId });
  }));
}

type AsyncHandler = (req: Request, res: Response) => Promise<void>;

function asyncRoute(handler: AsyncHandler) {
  return (req: Request, res: Response, next: NextFunction) => {
    handler(req, res).catch(next);
  };
}

function syncChannelValue(value: unknown): AdminSyncChannel | null {
  return value === 'shopify-products' || value === 'shopify-orders' ||
      value === 'storefront-content' || value === 'external-status'
    ? value
    : null;
}

function syncJobJson(job: AdminSyncJobRecord) {
  return {
    id: job.id,
    channel: job.channel,
    status: job.status,
    errorCode: job.errorCode,
    cursor: job.cursor,
    pagesProcessed: job.pagesProcessed,
    productsSeen: job.productsSeen,
    createdAt: job.createdAt.toISOString(),
    updatedAt: job.updatedAt.toISOString(),
  };
}

/** In-process lock so the same job is not double-executed after resume. */
const activeSyncJobs = new Set<string>();

/** Shopify Admin page size for product reconcile; completion requires exhausting pageInfo. */
const SYNC_PRODUCT_PAGE_SIZE = 100;
/** Hard stop to avoid unbounded loops; truncated jobs fail instead of claiming complete. */
const SYNC_PRODUCT_MAX_PAGES = 500;

async function runSyncJob(input: {
  readonly deps: AdminRouteDeps;
  readonly owner: Awaited<ReturnType<AdminAuthorizer['authenticate']>> & object;
  readonly jobId: string;
  readonly channel: AdminSyncChannel;
}): Promise<void> {
  const { deps, owner, jobId, channel } = input;
  const jobs = deps.syncJobs;
  if (jobs === undefined) return;
  if (activeSyncJobs.has(jobId)) return;
  activeSyncJobs.add(jobId);
  try {
    const existing = await jobs.find(jobId);
    if (existing === null) return;
    if (existing.status === 'completed' || existing.status === 'failed') return;

    await jobs.update({ id: jobId, status: 'running', errorCode: null });
    switch (channel) {
      case 'shopify-products': {
        if (deps.shopify === undefined) {
          throw new AdminRouteError(503, 'SHOPIFY_NOT_CONFIGURED', 'Shopify is not configured.');
        }
        let cursor = existing.cursor;
        let pagesProcessed = existing.pagesProcessed;
        let productsSeen = existing.productsSeen;
        for (;;) {
          if (pagesProcessed >= SYNC_PRODUCT_MAX_PAGES) {
            throw new AdminRouteError(
              503,
              'SYNC_TRUNCATED',
              'Product sync stopped before the catalog was fully read.',
            );
          }
          const page = await deps.shopify.listProducts({
            first: SYNC_PRODUCT_PAGE_SIZE,
            after: cursor,
          });
          pagesProcessed += 1;
          productsSeen += page.products.length;
          cursor = page.pageInfo.endCursor;
          await jobs.update({
            id: jobId,
            status: 'running',
            errorCode: null,
            cursor,
            pagesProcessed,
            productsSeen,
          });
          if (!page.pageInfo.hasNextPage) break;
          if (page.pageInfo.endCursor === null || page.pageInfo.endCursor === '') {
            throw new AdminRouteError(
              503,
              'SYNC_TRUNCATED',
              'Product sync received hasNextPage without an end cursor.',
            );
          }
        }
        break;
      }
      case 'storefront-content': {
        const client = storefrontClient(deps);
        if (client === null) {
          throw new AdminRouteError(503, 'STOREFRONT_NOT_CONFIGURED', 'Storefront is not configured.');
        }
        await client.getStorefrontConfig();
        await jobs.update({
          id: jobId,
          status: 'running',
          errorCode: null,
          pagesProcessed: 1,
          productsSeen: 0,
        });
        break;
      }
      case 'external-status': {
        // Kept for idempotent replay of older clients; product syncAll no longer calls it.
        if (deps.externalCatalog === undefined) {
          throw new AdminRouteError(
            503,
            'EXTERNAL_CATALOG_NOT_CONFIGURED',
            'The external catalog is not configured.',
          );
        }
        await deps.externalCatalog.fetchSources();
        await jobs.update({
          id: jobId,
          status: 'running',
          errorCode: null,
          pagesProcessed: 1,
          productsSeen: 0,
        });
        break;
      }
      case 'shopify-orders':
        throw new AdminRouteError(
          503,
          'SYNC_CHANNEL_NOT_CONFIGURED',
          'Shopify order reconciliation is not configured.',
        );
    }
    await jobs.update({ id: jobId, status: 'completed', errorCode: null });
    await recordSyncAudit(deps, owner, jobId, channel, 'success');
  } catch (error) {
    const errorCode = syncErrorCode(error);
    await jobs.update({ id: jobId, status: 'failed', errorCode });
    await recordSyncAudit(deps, owner, jobId, channel, 'failed', errorCode);
  } finally {
    activeSyncJobs.delete(jobId);
  }
}

/** Resume durable sync jobs that were left pending/running after a process restart. */
export async function resumeInterruptedSyncJobs(input: {
  readonly deps: AdminRouteDeps;
  readonly olderThanMs?: number;
}): Promise<number> {
  const jobs = input.deps.syncJobs;
  if (jobs === undefined || typeof jobs.listRecoverable !== 'function') return 0;
  const recoverable = await jobs.listRecoverable({
    olderThanMs: input.olderThanMs ?? 5_000,
    limit: 20,
  });
  for (const job of recoverable) {
    void runSyncJob({
      deps: input.deps,
      owner: {
        id: job.actorId,
        provider: 'monetta',
        subject: { type: 'app_account', id: job.actorId },
        role: 'owner',
      },
      jobId: job.id,
      channel: job.channel,
    });
  }
  return recoverable.length;
}

async function recordSyncAudit(
  deps: AdminRouteDeps,
  owner: Awaited<ReturnType<AdminAuthorizer['authenticate']>> & object,
  jobId: string,
  channel: AdminSyncChannel,
  outcome: 'success' | 'failed',
  errorCode?: string,
): Promise<void> {
  if (deps.audit === undefined) return;
  await deps.audit.record({
    actor: owner,
    requestId: `sync_${jobId}`,
    action: `sync.${channel}`,
    targetType: 'admin_sync_job',
    targetId: jobId,
    outcome,
    ...(errorCode === undefined ? {} : { errorCode }),
  });
}

function syncErrorCode(error: unknown): string {
  if (error instanceof AdminRouteError) return error.code;
  if (error instanceof ShopifyAdminError) return 'SHOPIFY_UPSTREAM_ERROR';
  return 'SYNC_FAILED';
}

function bearerCredential(req: Request): string | null {
  const authorization = req.header('Authorization');
  if (!authorization?.startsWith('Bearer ')) return null;
  const value = authorization.slice('Bearer '.length).trim();
  return value === '' || value.length > 8192 || /\s/.test(value) ? null : value;
}

async function requireOwner(
  req: Request,
  res: Response,
  authorizer: AdminAuthorizer,
) {
  const token = bearerCredential(req);
  if (token === null) {
    adminError(res, 401, 'UNAUTHORIZED', 'A valid session is required.');
    return null;
  }
  try {
    const owner = await authorizer.authenticate(token);
    if (owner === null) {
      adminError(res, 403, 'FORBIDDEN', 'This account cannot administer Monetta.');
      return null;
    }
    return owner;
  } catch (error) {
    if (error instanceof AdminAuthenticationUnavailableError) {
      adminError(res, 503, 'AUTHENTICATION_UNAVAILABLE', 'Authentication is temporarily unavailable.');
      return null;
    }
    throw error;
  }
}

function boundedLimit(value: unknown): number {
  const parsed = typeof value === 'string' ? Number.parseInt(value, 10) : NaN;
  return Number.isFinite(parsed) ? Math.max(1, Math.min(100, parsed)) : 50;
}

function nullableQueryString(value: unknown): string | null {
  if (typeof value !== 'string' || value.trim() === '' || value.length > 2048) return null;
  return value;
}

class AdminRouteError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message: string,
    readonly fields: Record<string, unknown> = {},
  ) {
    super(message);
    this.name = 'AdminRouteError';
  }
}

async function runProductMutation(input: {
  readonly req: Request;
  readonly res: Response;
  readonly deps: AdminRouteDeps;
  readonly owner: Awaited<ReturnType<AdminAuthorizer['authenticate']>> & object;
  readonly operation: string;
  readonly targetId: string;
  readonly body: Record<string, unknown>;
  readonly work: (client: ShopifyAdminWriteClient) => Promise<AdminProductProjection>;
}): Promise<void> {
  const { req, res, deps, owner, operation, targetId, body, work } = input;
  if (deps.mutationsEnabled !== true || deps.shopifyWritesEnabled !== true) {
    adminError(res, 503, 'MUTATIONS_DISABLED', 'Administrative writes are disabled.');
    return;
  }
  const client = deps.shopifyWrites;
  const idempotency = deps.idempotency;
  if (client === undefined || idempotency === undefined) {
    adminError(res, 503, 'MUTATIONS_NOT_CONFIGURED', 'Administrative writes are not configured.');
    return;
  }

  const idempotencyKey = req.header('Idempotency-Key')?.trim() ?? '';
  if (idempotencyKey === '' || idempotencyKey.length > 200 || /\s/.test(idempotencyKey)) {
    adminError(res, 400, 'IDEMPOTENCY_KEY_REQUIRED', 'Every mutation requires an Idempotency-Key.');
    return;
  }
  if (deps.rateLimiter !== undefined && !deps.rateLimiter.allow(owner.id, operation)) {
    adminError(res, 429, 'RATE_LIMITED', 'Too many administrative changes.');
    return;
  }

  const requestId = requestIdFor(res);
  const claim = await idempotency.claim({
    actorId: owner.id,
    idempotencyKey,
    operation,
    bodyHash: hashJson(body),
    requestId,
    expiresAt: new Date((deps.now ?? (() => new Date()))().getTime() + 24 * 60 * 60 * 1_000),
  });
  if (claim.outcome === 'conflict') {
    adminError(res, 409, 'IDEMPOTENCY_CONFLICT', 'The idempotency key was already used for another request.');
    return;
  }
  if (claim.outcome === 'replay') {
    res.status(claim.record.statusCode ?? 500).json(claim.record.responseBody);
    return;
  }

  let status = 200;
  let responseBody: unknown;
  let outcome: 'success' | 'failed' = 'success';
  let errorCode: string | undefined;
  try {
    const product = await work(client);
    responseBody = { requestId, product: productJson(product) };
  } catch (error) {
    outcome = 'failed';
    const mapped = mapMutationError(error);
    status = mapped.status;
    errorCode = mapped.code;
    responseBody = {
      error: {
        code: mapped.code,
        message: mapped.message,
        fields: mapped.fields,
        requestId,
      },
    };
  }

  await idempotency.complete({
    actorId: owner.id,
    idempotencyKey,
    statusCode: status,
    responseBody,
  });
  if (deps.audit !== undefined) {
    await deps.audit.record({
      actor: owner,
      requestId,
      action: operation,
      targetType: 'shopify_product',
      targetId,
      outcome,
      ...(errorCode === undefined ? {} : { errorCode }),
    });
  }
  res.status(status).json(responseBody);
}

async function runFeaturedMutation(input: {
  readonly req: Request;
  readonly res: Response;
  readonly deps: AdminRouteDeps;
  readonly owner: Awaited<ReturnType<AdminAuthorizer['authenticate']>> & object;
  readonly operation: string;
  readonly targetId: string;
  readonly body: Record<string, unknown>;
  readonly desiredProductIds: readonly string[];
  readonly expectedCollectionUpdatedAt: Date;
  readonly currentCollection?: AdminFeaturedCollectionProjection;
}): Promise<void> {
  const {
    req,
    res,
    deps,
    owner,
    operation,
    targetId,
    body,
    desiredProductIds,
  } = input;
  if (deps.mutationsEnabled !== true || deps.shopifyWritesEnabled !== true) {
    adminError(res, 503, 'MUTATIONS_DISABLED', 'Administrative writes are disabled.');
    return;
  }
  const client = featuredClient(deps);
  const idempotency = deps.idempotency;
  if (client === null || idempotency === undefined) {
    adminError(res, 503, 'MUTATIONS_NOT_CONFIGURED', 'Administrative writes are not configured.');
    return;
  }
  const idempotencyKey = req.header('Idempotency-Key')?.trim() ?? '';
  if (idempotencyKey === '' || idempotencyKey.length > 200 || /\s/.test(idempotencyKey)) {
    adminError(res, 400, 'IDEMPOTENCY_KEY_REQUIRED', 'Every mutation requires an Idempotency-Key.');
    return;
  }
  if (deps.rateLimiter !== undefined && !deps.rateLimiter.allow(owner.id, operation)) {
    adminError(res, 429, 'RATE_LIMITED', 'Too many administrative changes.');
    return;
  }

  const requestId = requestIdFor(res);
  const claim = await idempotency.claim({
    actorId: owner.id,
    idempotencyKey,
    operation,
    bodyHash: hashJson(body),
    requestId,
    expiresAt: new Date((deps.now ?? (() => new Date()))().getTime() + 24 * 60 * 60 * 1_000),
  });
  if (claim.outcome === 'conflict') {
    adminError(res, 409, 'IDEMPOTENCY_CONFLICT', 'The idempotency key was already used for another request.');
    return;
  }
  if (claim.outcome === 'replay') {
    res.status(claim.record.statusCode ?? 500).json(claim.record.responseBody);
    return;
  }

  let status = 200;
  let responseBody: unknown;
  let outcome: 'success' | 'failed' = 'success';
  let errorCode: string | undefined;
  try {
    const current = await requiredFeaturedCollection(client);
    assertCollectionFresh(current, input.expectedCollectionUpdatedAt);
    const eligible = await listEligibleProducts(client);
    const eligibleIds = new Set(eligible.map((product) => product.id));
    for (const productId of desiredProductIds) {
      if (!eligibleIds.has(productId)) {
        throw new AdminRouteError(
          422,
          'PRODUCT_NOT_ELIGIBLE',
          'Only active products published to Monetta can be featured.',
          { productId },
        );
      }
    }

    const remove = current.productIds.filter((id) => !desiredProductIds.includes(id));
    const add = desiredProductIds.filter((id) => !current.productIds.includes(id));
    if (remove.length > 0) await client.removeFeaturedProducts(remove);
    if (add.length > 0) await client.addFeaturedProducts(add);

    let afterMembership = await requiredFeaturedCollection(client);
    const moves = reorderMoves(afterMembership.productIds, desiredProductIds);
    let jobId: string | null = null;
    if (moves.length > 0) {
      const shopifyJobId = await client.reorderFeaturedProducts(moves);
      if (shopifyJobId === null || deps.featuredJobs === undefined) {
        throw new ShopifyAdminError('invalid_response', 'Shopify did not return a reorder job.');
      }
      jobId = randomUUID();
      await deps.featuredJobs.create({
        jobId,
        actorId: owner.id,
        shopifyJobId,
        collectionId: afterMembership.id,
        requestedProductIds: desiredProductIds,
      });
      status = 202;
      responseBody = {
        requestId,
        status: 'ordering',
        jobId,
        selectedProductIds: afterMembership.productIds,
      };
    } else {
      // The membership mutations are synchronous; still reread after them so
      // the response is Shopify truth rather than a local reconstruction.
      afterMembership = await requiredFeaturedCollection(client);
      const canonical = await readFeaturedCatalog(client);
      responseBody = { requestId, featuredCatalog: featuredCatalogJson(canonical) };
    }
  } catch (error) {
    outcome = 'failed';
    const mapped = mapFeaturedError(error);
    status = mapped.status;
    errorCode = mapped.code;
    responseBody = {
      error: {
        code: mapped.code,
        message: mapped.message,
        fields: mapped.fields,
        requestId,
      },
    };
  }

  await idempotency.complete({
    actorId: owner.id,
    idempotencyKey,
    statusCode: status,
    responseBody,
  });
  if (deps.audit !== undefined) {
    await deps.audit.record({
      actor: owner,
      requestId,
      action: operation,
      targetType: 'shopify_collection',
      targetId,
      outcome,
      ...(errorCode === undefined ? {} : { errorCode }),
    });
  }
  res.status(status).json(responseBody);
}

async function runStorefrontMutation(input: {
  readonly req: Request;
  readonly res: Response;
  readonly deps: AdminRouteDeps;
  readonly owner: Awaited<ReturnType<AdminAuthorizer['authenticate']>> & object;
  readonly body: Record<string, unknown>;
  readonly expectedVersion: number;
  readonly client: ShopifyAdminWriteClient;
}): Promise<void> {
  const { req, res, deps, owner, body, expectedVersion, client } = input;
  if (deps.mutationsEnabled !== true || deps.shopifyWritesEnabled !== true) {
    adminError(res, 503, 'MUTATIONS_DISABLED', 'Administrative writes are disabled.');
    return;
  }
  const idempotency = deps.idempotency;
  const idempotencyKey = req.header('Idempotency-Key')?.trim() ?? '';
  if (idempotency === undefined) {
    adminError(res, 503, 'MUTATIONS_NOT_CONFIGURED', 'Administrative writes are not configured.');
    return;
  }
  if (idempotencyKey === '' || idempotencyKey.length > 200 || /\s/.test(idempotencyKey)) {
    adminError(res, 400, 'IDEMPOTENCY_KEY_REQUIRED', 'Every mutation requires an Idempotency-Key.');
    return;
  }
  const operation = 'storefront-config.update';
  if (deps.rateLimiter !== undefined && !deps.rateLimiter.allow(owner.id, operation)) {
    adminError(res, 429, 'RATE_LIMITED', 'Too many administrative changes.');
    return;
  }

  const requestId = requestIdFor(res);
  const claim = await idempotency.claim({
    actorId: owner.id,
    idempotencyKey,
    operation,
    bodyHash: hashJson(body),
    requestId,
    expiresAt: new Date((deps.now ?? (() => new Date()))().getTime() + 24 * 60 * 60 * 1_000),
  });
  if (claim.outcome === 'conflict') {
    adminError(res, 409, 'IDEMPOTENCY_CONFLICT', 'The idempotency key was already used for another request.');
    return;
  }
  if (claim.outcome === 'replay') {
    res.status(claim.record.statusCode ?? 500).json(claim.record.responseBody);
    return;
  }

  let status = 200;
  let responseBody: unknown;
  let outcome: 'success' | 'failed' = 'success';
  let errorCode: string | undefined;
  try {
    const current = await client.getStorefrontConfig();
    const currentVersion = current?.version ?? 0;
    if (currentVersion !== expectedVersion) {
      throw new AdminRouteError(
        409,
        'STALE_RESOURCE',
        'The storefront configuration changed after it was loaded.',
        { expectedVersion, actualVersion: currentVersion },
      );
    }
    await client.updateStorefrontConfig({
      announcement: body.announcement as string,
      showHero: body.showHero as boolean,
      showNewest: body.showNewest as boolean,
      showTodaysPicks: body.showTodaysPicks as boolean,
      showExternalPicks: body.showExternalPicks as boolean,
      version: expectedVersion + 1,
    });
    const canonical = await client.getStorefrontConfig();
    if (canonical === null || canonical.version !== expectedVersion + 1) {
      throw new AdminRouteError(502, 'STOREFRONT_RECONCILIATION_FAILED', 'Storefront changes could not be confirmed.');
    }
    responseBody = { requestId, storefront: storefrontJson(canonical) };
  } catch (error) {
    outcome = 'failed';
    const mapped = mapMutationError(error);
    status = mapped.status;
    errorCode = mapped.code;
    responseBody = {
      error: { code: mapped.code, message: mapped.message, fields: mapped.fields, requestId },
    };
  }

  await idempotency.complete({
    actorId: owner.id,
    idempotencyKey,
    statusCode: status,
    responseBody,
  });
  if (deps.audit !== undefined) {
    await deps.audit.record({
      actor: owner,
      requestId,
      action: operation,
      targetType: 'shopify_metaobject',
      targetId: 'monetta',
      outcome,
      ...(errorCode === undefined ? {} : { errorCode }),
    });
  }
  res.status(status).json(responseBody);
}

async function runExternalPolicyMutation(input: {
  readonly req: Request;
  readonly res: Response;
  readonly deps: AdminRouteDeps;
  readonly owner: Awaited<ReturnType<AdminAuthorizer['authenticate']>> & object;
  readonly sourceId: string;
  readonly body: Record<string, unknown>;
  readonly policy: ExternalSourcePolicyInput;
  readonly client: ExternalCatalogAdminClient;
}): Promise<void> {
  const { req, res, deps, owner, sourceId, body, policy, client } = input;
  if (deps.mutationsEnabled !== true || deps.externalWritesEnabled !== true) {
    adminError(res, 503, 'EXTERNAL_WRITES_DISABLED', 'External policy writes are disabled.');
    return;
  }
  const idempotency = deps.idempotency;
  if (idempotency === undefined) {
    adminError(res, 503, 'MUTATIONS_NOT_CONFIGURED', 'Administrative writes are not configured.');
    return;
  }
  const idempotencyKey = req.header('Idempotency-Key')?.trim() ?? '';
  if (idempotencyKey === '' || idempotencyKey.length > 200 || /\s/.test(idempotencyKey)) {
    adminError(res, 400, 'IDEMPOTENCY_KEY_REQUIRED', 'Every mutation requires an Idempotency-Key.');
    return;
  }
  const operation = 'external-policy.update';
  if (deps.rateLimiter !== undefined && !deps.rateLimiter.allow(owner.id, operation)) {
    adminError(res, 429, 'RATE_LIMITED', 'Too many administrative changes.');
    return;
  }

  const requestId = requestIdFor(res);
  const claim = await idempotency.claim({
    actorId: owner.id,
    idempotencyKey,
    operation,
    bodyHash: hashJson(body),
    requestId,
    expiresAt: new Date((deps.now ?? (() => new Date()))().getTime() + 24 * 60 * 60 * 1_000),
  });
  if (claim.outcome === 'conflict') {
    adminError(res, 409, 'IDEMPOTENCY_CONFLICT', 'The idempotency key was already used for another request.');
    return;
  }
  if (claim.outcome === 'replay') {
    res.status(claim.record.statusCode ?? 500).json(claim.record.responseBody);
    return;
  }

  let status = 200;
  let responseBody: unknown;
  let outcome: 'success' | 'failed' = 'success';
  let errorCode: string | undefined;
  try {
    const source = await client.updateSource({ sourceId, source: policy, requestId });
    responseBody = { requestId, source };
  } catch (error) {
    outcome = 'failed';
    const mapped = mapExternalError(error);
    status = mapped.status;
    errorCode = mapped.code;
    responseBody = {
      error: { code: mapped.code, message: mapped.message, fields: {}, requestId },
    };
  }
  await idempotency.complete({
    actorId: owner.id,
    idempotencyKey,
    statusCode: status,
    responseBody,
  });
  if (deps.audit !== undefined) {
    await deps.audit.record({
      actor: owner,
      requestId,
      action: operation,
      targetType: 'external_source',
      targetId: sourceId,
      outcome,
      ...(errorCode === undefined ? {} : { errorCode }),
      after: { enabled: policy.enabled, itemLimit: policy.itemLimit },
    });
  }
  res.status(status).json(responseBody);
}

function featuredClient(deps: AdminRouteDeps): ShopifyAdminWriteClient | null {
  const candidate = deps.shopifyWrites;
  if (
    candidate === undefined ||
    typeof candidate.getFeaturedCollection !== 'function' ||
    typeof candidate.addFeaturedProducts !== 'function' ||
    typeof candidate.removeFeaturedProducts !== 'function' ||
    typeof candidate.reorderFeaturedProducts !== 'function' ||
    typeof candidate.getJob !== 'function'
  ) {
    return null;
  }
  return candidate;
}

function storefrontClient(deps: AdminRouteDeps): ShopifyAdminWriteClient | null {
  const candidate = deps.shopifyWrites;
  if (
    candidate === undefined ||
    typeof candidate.getStorefrontConfig !== 'function' ||
    typeof candidate.updateStorefrontConfig !== 'function'
  ) {
    return null;
  }
  return candidate;
}

async function requiredFeaturedCollection(
  client: ShopifyAdminWriteClient,
): Promise<AdminFeaturedCollectionProjection> {
  const collection = await client.getFeaturedCollection();
  if (collection === null) {
    throw new AdminRouteError(
      503,
      'FEATURED_COLLECTION_NOT_CONFIGURED',
      'Today\'s Picks is not configured.',
    );
  }
  if (collection.sortOrder !== 'MANUAL') {
    throw new AdminRouteError(
      503,
      'FEATURED_COLLECTION_NOT_MANUAL',
      'Today\'s Picks must use manual sorting.',
    );
  }
  return collection;
}

async function readFeaturedCatalog(
  client: ShopifyAdminWriteClient,
): Promise<AdminFeaturedCatalogProjection> {
  const [collection, eligibleProducts] = await Promise.all([
    client.getFeaturedCollection(),
    listEligibleProducts(client),
  ]);
  return {
    collection,
    eligibleProducts,
    selectedProductIds: collection?.productIds ?? [],
  };
}

async function listEligibleProducts(
  client: ShopifyAdminReadClient,
): Promise<readonly AdminProductProjection[]> {
  const page = await client.listProducts({ first: 100, after: null });
  return page.products.filter(
    (product) => product.status === 'ACTIVE' && product.publishedOnPublication,
  );
}

function featuredCatalogJson(projection: AdminFeaturedCatalogProjection) {
  return {
    collection: projection.collection === null ? null : {
      id: projection.collection.id,
      handle: projection.collection.handle,
      title: projection.collection.title,
      updatedAt: projection.collection.updatedAt,
      sortOrder: projection.collection.sortOrder,
    },
    eligibleProducts: projection.eligibleProducts.map(productJson),
    selectedProductIds: projection.selectedProductIds,
  };
}

function assertCollectionFresh(
  collection: AdminFeaturedCollectionProjection,
  expected: Date,
): void {
  const actual = new Date(collection.updatedAt);
  if (Number.isNaN(actual.getTime()) || actual.getTime() !== expected.getTime()) {
    throw new AdminRouteError(
      409,
      'STALE_RESOURCE',
      'Today\'s Picks changed after it was loaded.',
      { expectedCollectionUpdatedAt: expected.toISOString(), actualCollectionUpdatedAt: collection.updatedAt },
    );
  }
}

function reorderMoves(
  current: readonly string[],
  desired: readonly string[],
): Array<{ id: string; newPosition: number }> {
  const working = [...current];
  const moves: Array<{ id: string; newPosition: number }> = [];
  for (let index = 0; index < desired.length; index += 1) {
    const id = desired[index];
    if (id === undefined) continue;
    const currentIndex = working.indexOf(id);
    if (currentIndex === -1) continue;
    if (currentIndex === index) continue;
    working.splice(currentIndex, 1);
    working.splice(index, 0, id);
    moves.push({ id, newPosition: index });
  }
  return moves;
}

function arraysEqual(left: readonly string[], right: readonly string[]): boolean {
  return left.length === right.length && left.every((value, index) => value === right[index]);
}

function productIdsValue(value: unknown): string[] | null {
  if (!Array.isArray(value) || value.length > 12) return null;
  const ids = value.filter((item): item is string => typeof item === 'string');
  if (ids.length !== value.length || new Set(ids).size !== ids.length) return null;
  return ids.every((id) => productGidValue(id) !== null) ? ids : null;
}

function externalSourceIdValue(value: string | undefined): string | null {
  return value !== undefined && /^[a-z0-9_]{1,80}$/.test(value) ? value : null;
}

function externalPolicyValue(value: Record<string, unknown>): ExternalSourcePolicyInput | null {
  const enabled = booleanValue(value.enabled);
  const itemLimit = value.itemLimit;
  const baseCommissionRate = value.baseCommissionRate;
  const highValueCommissionRate = value.highValueCommissionRate;
  const highValueThreshold = value.highValueThreshold;
  if (
    enabled === null ||
    !Number.isInteger(itemLimit) || (itemLimit as number) < 0 || (itemLimit as number) > 50 ||
    typeof baseCommissionRate !== 'number' || !Number.isFinite(baseCommissionRate) ||
    baseCommissionRate < 0 || baseCommissionRate > 1 ||
    typeof highValueCommissionRate !== 'number' || !Number.isFinite(highValueCommissionRate) ||
    highValueCommissionRate < 0 || highValueCommissionRate > 1 ||
    typeof highValueThreshold !== 'number' || !Number.isFinite(highValueThreshold) ||
    highValueThreshold <= 0 || highValueThreshold > 1_000_000
  ) {
    return null;
  }
  return {
    enabled,
    itemLimit: itemLimit as number,
    baseCommissionRate,
    highValueCommissionRate,
    highValueThreshold,
  };
}

function integerValue(value: unknown): number | null {
  return typeof value === 'number' && Number.isSafeInteger(value) && value >= 0 ? value : null;
}

function textValue(value: unknown, max: number): string | null {
  if (typeof value !== 'string' || value.length > max) return null;
  return value.trim();
}

function storefrontJson(config: AdminStorefrontConfigProjection) {
  return {
    id: config.id,
    version: config.version,
    announcement: config.announcement,
    showHero: config.showHero,
    showNewest: config.showNewest,
    showTodaysPicks: config.showTodaysPicks,
    showExternalPicks: config.showExternalPicks,
  };
}

function mapFeaturedError(error: unknown): {
  status: number;
  code: string;
  message: string;
  fields: Record<string, unknown>;
} {
  if (error instanceof AdminRouteError) {
    return { status: error.status, code: error.code, message: error.message, fields: error.fields };
  }
  if (error instanceof ShopifyAdminUserError) {
    return {
      status: 422,
      code: 'SHOPIFY_VALIDATION_ERROR',
      message: 'Shopify rejected the featured catalog change.',
      fields: {},
    };
  }
  if (error instanceof ShopifyAdminError) {
    if (error.code === 'not_configured') {
      return { status: 503, code: 'FEATURED_COLLECTION_NOT_CONFIGURED', message: 'Today\'s Picks is not configured.', fields: {} };
    }
    if (error.code === 'throttled') {
      return { status: 429, code: 'SHOPIFY_THROTTLED', message: 'Shopify could not confirm the change.', fields: {} };
    }
  }
  return { status: 502, code: 'SHOPIFY_UPSTREAM_ERROR', message: 'Shopify could not confirm the featured catalog change.', fields: {} };
}

function featuredError(
  res: Response,
  mapped: { status: number; code: string; message: string; fields: Record<string, unknown> },
): void {
  const requestId = requestIdFor(res);
  res.status(mapped.status).json({
    error: { code: mapped.code, message: mapped.message, fields: mapped.fields, requestId },
  });
}

function shopifyErrorCodeFor(error: unknown): string {
  if (error instanceof ShopifyAdminError && error.code === 'throttled') return 'SHOPIFY_THROTTLED';
  return 'SHOPIFY_UPSTREAM_ERROR';
}

function featuredErrorCodeFor(error: unknown): string {
  if (error instanceof ShopifyAdminError) {
    if (error.code === 'not_configured') return 'FEATURED_COLLECTION_NOT_CONFIGURED';
    if (error.code === 'throttled') return 'SHOPIFY_THROTTLED';
  }
  return 'FEATURED_UPSTREAM_ERROR';
}

async function currentProduct(
  client: ShopifyAdminWriteClient,
  productGid: string,
): Promise<AdminProductProjection> {
  const product = await client.getProduct(productGid);
  if (product === null) throw new AdminRouteError(404, 'PRODUCT_NOT_FOUND', 'The product was not found.');
  return product;
}

async function canonicalProduct(
  client: ShopifyAdminWriteClient,
  productGid: string,
): Promise<AdminProductProjection> {
  return currentProduct(client, productGid);
}

function assertFresh(product: AdminProductProjection, expected: Date): void {
  const actual = new Date(product.updatedAt);
  if (Number.isNaN(actual.getTime()) || actual.getTime() !== expected.getTime()) {
    throw new AdminRouteError(
      409,
      'STALE_RESOURCE',
      'The product changed after it was loaded.',
      { expectedUpdatedAt: expected.toISOString(), actualUpdatedAt: product.updatedAt },
    );
  }
}

function mapMutationError(error: unknown): {
  status: number;
  code: string;
  message: string;
  fields: Record<string, unknown>;
} {
  if (error instanceof AdminRouteError) {
    return { status: error.status, code: error.code, message: error.message, fields: error.fields };
  }
  if (error instanceof ShopifyAdminUserError) {
    return {
      status: 422,
      code: 'SHOPIFY_VALIDATION_ERROR',
      message: 'Shopify rejected the requested change.',
      fields: {},
    };
  }
  if (error instanceof ShopifyAdminError) {
    return {
      status: error.code === 'throttled' ? 429 : 502,
      code: error.code === 'throttled' ? 'SHOPIFY_THROTTLED' : 'SHOPIFY_UPSTREAM_ERROR',
      message: 'Shopify could not confirm the change.',
      fields: {},
    };
  }
  return {
    status: 502,
    code: 'SHOPIFY_UPSTREAM_ERROR',
    message: 'Shopify could not confirm the change.',
    fields: {},
  };
}

function errorCodeForExternal(error: unknown): string {
  return error instanceof Error && 'code' in error && typeof error.code === 'string'
    ? error.code
    : 'EXTERNAL_CATALOG_UPSTREAM_ERROR';
}

function mapExternalError(error: unknown): {
  status: number;
  code: string;
  message: string;
} {
  if (error instanceof AdminRouteError) {
    return { status: error.status, code: error.code, message: error.message };
  }
  const statusCode = error instanceof Error && 'statusCode' in error &&
      typeof error.statusCode === 'number'
    ? error.statusCode
    : undefined;
  const code = errorCodeForExternal(error);
  return {
    status: statusCode === 401 ? 502 : statusCode === 429 ? 429 : 502,
    code: statusCode === 429 ? 'EXTERNAL_CATALOG_THROTTLED' : code,
    message: 'The external catalog could not confirm the request.',
  };
}

function requestIdFor(res: Response): string {
  return (res.locals.requestId as string | undefined) ?? `req_${createHash('sha256').update(String(Date.now())).digest('hex').slice(0, 16)}`;
}

function auditReaderFor(deps: AdminRouteDeps): AdminAuditReader | null {
  if (deps.auditReader !== undefined) return deps.auditReader;
  const candidate = deps.audit as Partial<AdminAuditReader> | undefined;
  return candidate !== undefined && typeof candidate.list === 'function'
    ? candidate as AdminAuditReader
    : null;
}

function decodeAuditCursor(value: string | null): number | null | undefined {
  if (value === null) return null;
  try {
    const decoded = Buffer.from(value, 'base64url').toString('utf8');
    const id = Number(decoded);
    return /^\d+$/.test(decoded) && Number.isSafeInteger(id) && id > 0 ? id : undefined;
  } catch (_) {
    return undefined;
  }
}

function encodeAuditCursor(id: number): string {
  return Buffer.from(String(id), 'utf8').toString('base64url');
}

function auditJson(record: import('./mutationPorts.js').AdminAuditRecord) {
  const metadata = record.metadata;
  return {
    id: encodeAuditCursor(record.id),
    actorId: record.actorId,
    action: record.action,
    targetType: record.resourceType,
    targetId: record.resourceId,
    outcome: typeof metadata.outcome === 'string' ? metadata.outcome : 'success',
    requestId: typeof metadata.requestId === 'string' ? metadata.requestId : null,
    errorCode: typeof metadata.errorCode === 'string' ? metadata.errorCode : null,
    before: boundedAuditValue(metadata.before),
    after: boundedAuditValue(metadata.after),
    createdAt: record.createdAt.toISOString(),
  };
}

function boundedAuditValue(value: unknown): Record<string, unknown> | null {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) return null;
  const entries = Object.entries(value as Record<string, unknown>).slice(0, 20);
  return Object.fromEntries(entries.map(([key, item]) => [key, auditScalar(item)]));
}

function auditScalar(value: unknown): unknown {
  if (value === null || typeof value === 'string' || typeof value === 'number' || typeof value === 'boolean') {
    return value;
  }
  if (Array.isArray(value)) return value.slice(0, 10).map(auditScalar);
  return '[redacted]';
}

function hashJson(value: unknown): string {
  return createHash('sha256').update(JSON.stringify(sortJson(value))).digest('hex');
}

function sortJson(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(sortJson);
  if (value !== null && typeof value === 'object') {
    return Object.fromEntries(
      Object.entries(value as Record<string, unknown>)
        .sort(([a], [b]) => a.localeCompare(b))
        .map(([key, item]) => [key, sortJson(item)]),
    );
  }
  return value;
}

function productGidValue(value: string | undefined): string | null {
  return value !== undefined && /^gid:\/\/shopify\/Product\/\d+$/.test(value) ? value : null;
}

function variantGidValue(value: string | undefined): string | null {
  return value !== undefined && /^gid:\/\/shopify\/ProductVariant\/\d+$/.test(value) ? value : null;
}

function stringValue(value: unknown, max: number): string | null {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  return trimmed === '' || trimmed.length > max ? null : trimmed;
}

function plainObject(value: unknown): Record<string, unknown> | null {
  return value !== null && typeof value === 'object' && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null;
}

function instantValue(value: unknown): Date | null {
  if (typeof value !== 'string' || value.length > 80) return null;
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function moneyValue(value: unknown): string | null {
  if (typeof value !== 'string' || !/^\d{1,8}(?:\.\d{1,2})?$/.test(value.trim())) return null;
  const normalized = value.trim();
  return Number(normalized) > 0 ? normalized : null;
}

function booleanValue(value: unknown): boolean | null {
  return typeof value === 'boolean' ? value : null;
}

function productJson(product: AdminProductProjection) {
  const prices = product.variants
    .map((variant) => Number(variant.price))
    .filter((price) => Number.isFinite(price));
  return {
    id: product.id,
    title: product.title,
    descriptionHtml: product.descriptionHtml ?? '',
    imageUrl: product.imageUrl ?? null,
    updatedAt: product.updatedAt,
    status: product.status,
    publishedToMonetta: product.publishedOnPublication,
    // Compatibility fields for the current preview UI. The canonical
    // projection remains variants[], and no write route consumes these values.
    price: prices.length === 0 ? 0 : Math.min(...prices),
    inStock: product.variants.some((variant) => variant.availableForSale),
    visible: product.publishedOnPublication,
    variantCount: product.variants.length,
    currencyCode: product.currencyCode ?? product.variants[0]?.currencyCode ?? 'MXN',
    variants: product.variants,
  };
}

function adminError(
  res: Response,
  status: number,
  code: string,
  message: string,
): void {
  const requestId = res.locals.requestId as string | undefined;
  res.status(status).json({
    error: {
      code,
      message,
      fields: {},
      ...(requestId === undefined ? {} : { requestId }),
    },
  });
}
