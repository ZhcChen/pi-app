import { join } from 'node:path';
import { pathToFileURL } from 'node:url';

import { getPackageDir } from '@earendil-works/pi-coding-agent';

import { JsonlWriter } from './protocol.js';

type PiOutputGuard = {
  takeOverStdout(): void;
  writeRawStdout(text: string): void;
  waitForRawStdoutBackpressure(): Promise<void>;
};

export async function createGuardedJsonlWriter(): Promise<JsonlWriter> {
  const modulePath = join(getPackageDir(), 'dist', 'core', 'output-guard.js');
  const outputGuard = (await import(
    pathToFileURL(modulePath).href
  )) as PiOutputGuard;

  outputGuard.takeOverStdout();
  return new JsonlWriter(async (line) => {
    outputGuard.writeRawStdout(line);
    await outputGuard.waitForRawStdoutBackpressure();
  });
}
