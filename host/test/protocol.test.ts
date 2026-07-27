import assert from 'node:assert/strict';
import test from 'node:test';
import { spawn } from 'node:child_process';
import { once } from 'node:events';
import { Readable, Writable } from 'node:stream';

import {
  JsonlWriter,
  parsePiHostRequest,
  PiHostProtocolError,
  readJsonl,
} from '../src/protocol.js';

class CaptureWritable extends Writable {
  readonly chunks: string[] = [];

  override _write(
    chunk: Buffer,
    _encoding: BufferEncoding,
    callback: (error?: Error | null) => void,
  ): void {
    this.chunks.push(chunk.toString('utf8'));
    callback();
  }

  text(): string {
    return this.chunks.join('');
  }
}

test('JSONL parser uses LF framing without splitting valid unicode separators', async () => {
  const text = `first\u2028second\u2029third`;
  const records: unknown[] = [];
  const input = Readable.from([
    Buffer.from(`${JSON.stringify({ id: 'req-1', text })}\n`, 'utf8'),
  ]);

  await readJsonl(input, async (record) => {
    records.push(record);
  });

  assert.deepEqual(records, [{ id: 'req-1', text }]);
});

test('JSONL writer serializes protocol records one per line', async () => {
  const output = new CaptureWritable();
  const writer = new JsonlWriter(output);

  await Promise.all([
    writer.write({ type: 'event', event: 'run.started', sessionId: 'session-a' }),
    writer.write({
      type: 'response',
      id: 'req-1',
      ok: true,
      result: { accepted: true },
    }),
  ]);
  await writer.flush();

  const records = output
    .text()
    .trim()
    .split('\n')
    .map((line) => JSON.parse(line));
  assert.equal(records.length, 2);
  assert.equal(records[0].type, 'event');
  assert.equal(records[1].type, 'response');
});

test('JSONL writer rejects a record above the protocol size limit', () => {
  const writer = new JsonlWriter(new CaptureWritable());

  assert.throws(
    () =>
      writer.write({
        type: 'response',
        id: 'large-record',
        ok: true,
        result: { text: 'x'.repeat(1024 * 1024) },
      }),
    PiHostProtocolError,
  );
});

test('guarded JSONL writer keeps ordinary stdout diagnostics off the protocol stream', async () => {
  const outputGuardUrl = new URL('../src/output_guard.js', import.meta.url).href;
  const script = [
    `import { createGuardedJsonlWriter } from ${JSON.stringify(outputGuardUrl)};`,
    'const writer = await createGuardedJsonlWriter();',
    "console.log('extension diagnostic');",
    "await writer.write({ type: 'event', event: 'runtime.diagnostic', data: { message: 'protocol event' } });",
  ].join('\n');
  const child = spawn(process.execPath, ['--input-type=module', '--eval', script], {
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  let stdout = '';
  let stderr = '';
  child.stdout.setEncoding('utf8');
  child.stderr.setEncoding('utf8');
  child.stdout.on('data', (chunk: string) => {
    stdout += chunk;
  });
  child.stderr.on('data', (chunk: string) => {
    stderr += chunk;
  });
  const [exitCode] = (await once(child, 'close')) as [number];

  assert.equal(exitCode, 0);
  assert.deepEqual(JSON.parse(stdout), {
    type: 'event',
    event: 'runtime.diagnostic',
    data: { message: 'protocol event' },
  });
  assert.match(stderr, /extension diagnostic/);
});

test('request parser rejects unsupported protocol shapes', () => {
  assert.throws(
    () => parsePiHostRequest({ id: '', method: 'host.health' }),
    PiHostProtocolError,
  );
  assert.throws(
    () => parsePiHostRequest({ id: 'req-1', method: 'unknown' }),
    PiHostProtocolError,
  );
});
