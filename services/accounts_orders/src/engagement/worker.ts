#!/usr/bin/env node
import { loadConfig } from '../config.js';
import { getPool, closePool } from '../db/pool.js';
import { logger } from '../logger.js';
import { EngagementService } from './application/engagementService.js';
import { RegistrationCipher } from './crypto/registrationCipher.js';
import { FcmMessagingProvider } from './infrastructure/fcmMessagingProvider.js';
import { GoogleAccessTokenProvider } from './infrastructure/googleAccessTokenProvider.js';
import { PgEngagementRepository } from './infrastructure/pgEngagementRepository.js';

const config = loadConfig();
if (!config.notificationsEnabled) {
  logger.error('notification worker cannot start while NOTIFICATIONS_ENABLED is false');
  process.exitCode = 1;
} else {
  const pool = getPool();
  const tokens = new GoogleAccessTokenProvider(
    config.firebaseClientEmail,
    config.firebasePrivateKey,
  );
  const service = new EngagementService(
    new PgEngagementRepository(
      pool,
      RegistrationCipher.fromSecret(config.pushTokenEncryptionSecret),
    ),
    new FcmMessagingProvider(config.firebaseProjectId, tokens),
  );

  let stopping = false;
  const stop = () => { stopping = true; };
  process.once('SIGTERM', stop);
  process.once('SIGINT', stop);

  try {
    while (!stopping) {
      const result = await service.dispatchOnce(100);
      if (result.materialized > 0 || result.processed > 0) {
        logger.info('notification worker batch complete', result);
      }
      await delay(result.processed === 0 ? 5_000 : 250);
    }
  } catch (error) {
    logger.error('notification worker stopped after an unhandled error', {
      error: error instanceof Error ? error.name : typeof error,
    });
    process.exitCode = 1;
  } finally {
    await closePool();
  }
}

function delay(milliseconds: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}
