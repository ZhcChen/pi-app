import assert from 'node:assert/strict';
import { mkdtemp, readFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';

import {
  PiRpcHarness,
  PiRpcHarnessError,
  StrictPiRpcJsonlDecoder,
  piRpcMaxJsonlRecordBytes,
} from '../src/pi_rpc_harness.js';

test('Pi RPC decoder uses LF framing and preserves Unicode separators', () => {
  const decoder = new StrictPiRpcJsonlDecoder();
  const text = 'first\u2028second\u2029third';
  const records = decoder.push(Buffer.from(`${JSON.stringify({ text })}\n`, 'utf8'));

  assert.deepEqual(records, [{ text }]);
  assert.deepEqual(decoder.finish(), []);
});

test('Pi RPC decoder accepts CRLF records split across chunks', () => {
  const decoder = new StrictPiRpcJsonlDecoder();

  assert.deepEqual(decoder.push('{"id":"one"}\r'), []);
  assert.deepEqual(decoder.push('\n{"id":"two"}\n'), [{ id: 'one' }, { id: 'two' }]);
  assert.deepEqual(decoder.finish(), []);
});

test('Pi RPC decoder rejects oversized and unterminated records', () => {
  const oversized = new StrictPiRpcJsonlDecoder();
  assert.throws(
    () => oversized.push('x'.repeat(piRpcMaxJsonlRecordBytes + 1)),
    PiRpcHarnessError,
  );

  const unterminated = new StrictPiRpcJsonlDecoder();
  unterminated.push('{"id":"missing-newline"}');
  assert.throws(() => unterminated.finish(), PiRpcHarnessError);
});

test('Pi RPC harness correlates responses and records LF JSONL traffic', async () => {
  const outputDir = await mkdtemp(join(tmpdir(), 'pi-rpc-harness-test-'));
  const recordFile = join(outputDir, 'recording.jsonl');
  const childScript = [
    'let buffer = "";',
    'process.stdin.setEncoding("utf8");',
    'process.stdin.on("data", (chunk) => {',
    '  buffer += chunk;',
    '  while (true) {',
    '    const newline = buffer.indexOf("\\n");',
    '    if (newline < 0) break;',
    '    const line = buffer.slice(0, newline);',
    '    buffer = buffer.slice(newline + 1);',
    '    if (line.length === 0) continue;',
    '    const request = JSON.parse(line);',
    '    process.stdout.write(JSON.stringify({ type: "response", id: request.id, command: request.type, success: true }) + "\\n");',
    '  }',
    '});',
  ].join('\n');

  const harness = await PiRpcHarness.start({
    executable: process.execPath,
    args: ['--input-type=module', '--eval', childScript],
    cwd: outputDir,
    recordFile,
  });

  try {
    const response = await harness.request({ id: 'state-1', type: 'get_state' });
    assert.deepEqual(response, {
      type: 'response',
      id: 'state-1',
      command: 'get_state',
      success: true,
    });

    await harness.close();
    const recording = await readFile(recordFile, 'utf8');
    const records = recording
      .trim()
      .split('\n')
      .map((line) => JSON.parse(line) as { direction: string; value: { type?: string } });
    assert.equal(records.some((record) => record.direction === 'stdin'), true);
    assert.equal(
      records.some(
        (record) => record.direction === 'stdout' && record.value.type === 'response',
      ),
      true,
    );
  } finally {
    await harness.close();
    await rm(outputDir, { force: true, recursive: true });
  }
});
