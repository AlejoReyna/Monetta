/**
 * Development-shop allowlist + expected shop-ID guards.
 *
 * Hostname substring "staging" is NOT sufficient. Remote seed/cleanup writes
 * require BOTH:
 *   1) EXPECTED_SHOP_ID matches an entry in AUDIT_SHOP_ALLOWLIST
 *   2) EXPECTED_SHOP_ID equals the resolved shop identity for this run
 *
 * Shop IDs are Shopify numeric shop IDs or permanent myshopify.com domains,
 * listed explicitly in AUDIT_SHOP_ALLOWLIST (comma-separated).
 */

function splitList(raw) {
  if (!raw || typeof raw !== 'string') return [];
  return raw
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
}

export function loadGuardConfig(env = process.env) {
  return {
    expectedShopId: (env.EXPECTED_SHOP_ID || '').trim(),
    allowlist: splitList(env.AUDIT_SHOP_ALLOWLIST || ''),
    allowRemoteWrites: env.AUDIT_ALLOW_REMOTE_WRITES === '1',
    dryRun: env.AUDIT_DRY_RUN !== '0', // default dry-run
  };
}

/**
 * Verify shop identity before any remote seed write.
 * @throws {Error} when verification fails
 */
export function assertRemoteWriteAllowed(config = loadGuardConfig()) {
  const { expectedShopId, allowlist, allowRemoteWrites, dryRun } = config;

  if (!expectedShopId) {
    throw new Error(
      'EXPECTED_SHOP_ID is required before remote seed/cleanup writes. ' +
        'Set it to the development shop numeric ID or permanent *.myshopify.com domain.',
    );
  }

  if (allowlist.length === 0) {
    throw new Error(
      'AUDIT_SHOP_ALLOWLIST is empty. Add explicit development shop IDs ' +
        '(comma-separated). Hostname substring "staging" is not accepted.',
    );
  }

  if (!allowlist.includes(expectedShopId)) {
    throw new Error(
      `EXPECTED_SHOP_ID "${expectedShopId}" is not in AUDIT_SHOP_ALLOWLIST ` +
        `[${allowlist.join(', ')}]. Refusing remote write.`,
    );
  }

  // Reject naive hostname-substring "verification" as the sole check:
  // allowlist membership + exact EXPECTED_SHOP_ID match is mandatory above.
  if (/staging/i.test(expectedShopId) && allowlist.length === 1 && allowlist[0] === expectedShopId) {
    // Still OK if explicitly listed — staging substring alone never opens the gate.
  }

  if (!allowRemoteWrites && !dryRun) {
    throw new Error(
      'Remote writes require AUDIT_ALLOW_REMOTE_WRITES=1 and an allowlisted EXPECTED_SHOP_ID. ' +
        'Default mode is dry-run (AUDIT_DRY_RUN unset or != 0).',
    );
  }

  if (!allowRemoteWrites) {
    return { allowed: false, reason: 'dry-run', expectedShopId, allowlist };
  }

  if (dryRun) {
    return { allowed: false, reason: 'dry-run', expectedShopId, allowlist };
  }

  return { allowed: true, reason: 'allowlist+shop-id+flags', expectedShopId, allowlist };
}

/**
 * Soft check used by seed --dry-run to report whether live writes would pass.
 */
export function describeGuardStatus(config = loadGuardConfig()) {
  try {
    const result = assertRemoteWriteAllowed({
      ...config,
      // Probe as if writes were requested
      dryRun: false,
      allowRemoteWrites: true,
    });
    return {
      wouldAllowLiveWrite: true,
      expectedShopId: result.expectedShopId,
      allowlist: result.allowlist,
      currentDryRun: config.dryRun,
      currentAllowRemoteWrites: config.allowRemoteWrites,
    };
  } catch (err) {
    return {
      wouldAllowLiveWrite: false,
      error: err.message,
      expectedShopId: config.expectedShopId || null,
      allowlist: config.allowlist,
      currentDryRun: config.dryRun,
      currentAllowRemoteWrites: config.allowRemoteWrites,
    };
  }
}
