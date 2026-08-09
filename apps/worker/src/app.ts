import Fastify, { type FastifyInstance } from 'fastify';

import { today } from '@warq/core';

import type { WorkerConfig } from './config.js';

/**
 * Builds the worker's HTTP surface.
 *
 * The worker is mostly a scheduler, but it needs an HTTP server for Railway's
 * health checks — and, from M8, to accept report-generation requests.
 */
export function buildApp(config: WorkerConfig): FastifyInstance {
  const app = Fastify({
    logger: {
      level: config.environment === 'production' ? 'info' : 'debug',
      // Never let a service-role key reach the logs.
      redact: ['req.headers.authorization', 'req.headers["x-supabase-key"]'],
    },
    disableRequestLogging: config.environment === 'test',
  });

  /** Liveness: the process is up. Railway restarts the container if this fails. */
  app.get('/health', () => ({ status: 'ok', date: today() }));

  /**
   * Readiness: the process is up *and* has what it needs to do work.
   * Until M7 wires Supabase in, the worker has no dependencies, so it is ready
   * as soon as it starts.
   */
  app.get('/ready', async (_request, reply) => {
    const dependencies = {
      supabase: config.supabaseUrl === null ? 'not configured' : 'configured',
    };

    const ready = true;
    return reply.code(ready ? 200 : 503).send({ ready, dependencies });
  });

  app.get('/', () => ({
    service: 'warq-worker',
    responsibilities: [
      'Move subscriptions between active, expiring soon and expired',
      'Send expiry reminders on the configured schedule',
      'Send absence alerts to guardians',
      'Render student, class, organization and platform reports',
    ],
    note: 'Scheduled jobs land in M7; report rendering lands in M8.',
  }));

  return app;
}
