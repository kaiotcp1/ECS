import { afterAll, describe, expect, it } from 'vitest';

import { buildApp } from '../src/app.js';

const app = buildApp({ LOG_LEVEL: 'silent' });

afterAll(async () => {
  await app.close();
});

describe('app', () => {
  it('responds on GET /', async () => {
    const response = await app.inject({
      method: 'GET',
      url: '/'
    });

    expect(response.statusCode).toBe(200);
    expect(response.json()).toEqual({
      name: 'FargateFlow',
      status: 'ok'
    });
  });

  it('responds on GET /health', async () => {
    const response = await app.inject({
      method: 'GET',
      url: '/health'
    });

    expect(response.statusCode).toBe(200);
    expect(response.json()).toEqual({
      status: 'ok'
    });
  });
});
