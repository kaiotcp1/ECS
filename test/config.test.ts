import { describe, expect, it } from 'vitest';

import { loadConfig } from '../src/config.js';

describe('loadConfig', () => {
  it('uses defaults for missing optional environment variables', () => {
    expect(loadConfig({})).toEqual({
      NODE_ENV: 'development',
      HOST: '0.0.0.0',
      PORT: 3000,
      LOG_LEVEL: 'info'
    });
  });

  it('coerces and validates provided environment variables', () => {
    expect(
      loadConfig({
        NODE_ENV: 'test',
        HOST: '127.0.0.1',
        PORT: '8080',
        LOG_LEVEL: 'debug'
      })
    ).toEqual({
      NODE_ENV: 'test',
      HOST: '127.0.0.1',
      PORT: 8080,
      LOG_LEVEL: 'debug'
    });
  });

  it('throws for invalid environment variables', () => {
    expect(() => loadConfig({ PORT: '70000' })).toThrow(
      'Invalid environment configuration'
    );
  });
});
