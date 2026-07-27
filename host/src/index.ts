import { protocolVersion } from './protocol.js';
import { createGuardedJsonlWriter } from './output_guard.js';
import { PiSdkSessionFactory } from './pi_sdk_session.js';
import { PiHostServer } from './server.js';

async function main(): Promise<void> {
  const writer = await createGuardedJsonlWriter();
  const server = new PiHostServer({
    factory: new PiSdkSessionFactory(),
    writer,
  });
  let shuttingDown = false;

  const shutdown = async (): Promise<void> => {
    if (shuttingDown) {
      return;
    }
    shuttingDown = true;
    await server.dispose();
  };

  process.once('SIGINT', () => {
    void shutdown().finally(() => process.exit(0));
  });
  process.once('SIGTERM', () => {
    void shutdown().finally(() => process.exit(0));
  });

  try {
    await server.run(process.stdin);
  } finally {
    await shutdown();
  }
}

void main().catch((error: unknown) => {
  const message = error instanceof Error ? error.stack ?? error.message : String(error);
  process.stderr.write(`[pi-host v${protocolVersion}] ${message}\n`);
  process.exitCode = 1;
});
