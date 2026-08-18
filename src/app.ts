import Fastify, { type FastifyError, type FastifyInstance } from 'fastify';

import type { AppConfig } from './config.js';

type AppOptions = Pick<AppConfig, 'LOG_LEVEL'>;

export function buildApp(
  options: AppOptions = { LOG_LEVEL: 'info' }
): FastifyInstance {
  const app = Fastify({
    logger: {
      level: options.LOG_LEVEL
    }
  });

  app.get('/', async () => ({
    name: 'FargateFlow',
    status: 'ok'
  }));

  app.get('/health', async () => ({
    status: 'ok'
  }));

  app.setErrorHandler((error: FastifyError, request, reply) => {
    request.log.error({ err: error }, 'request failed');

    const statusCode =
      typeof error.statusCode === 'number' && error.statusCode >= 400
        ? error.statusCode
        : 500;

    void reply.status(statusCode).send({
      error: statusCode >= 500 ? 'Internal Server Error' : error.message
    });
  });

  return app;
}
