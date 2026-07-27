import assert from 'node:assert/strict';
import test from 'node:test';
import { Writable } from 'node:stream';

import { JsonlWriter, type PiHostEvent, type PiHostModel, type PiHostSessionSnapshot } from '../src/protocol.js';
import { PiHostServer, type PiHostSession, type PiHostSessionFactory } from '../src/server.js';

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

  records(): Array<Record<string, unknown>> {
    return this.chunks
      .join('')
      .trim()
      .split('\n')
      .filter((line) => line.length > 0)
      .map((line) => JSON.parse(line) as Record<string, unknown>);
  }
}

const model: PiHostModel = {
  provider: 'openai',
  id: 'gpt-5.4',
  name: 'GPT-5.4',
  reasoning: true,
};

class FakeSession implements PiHostSession {
  readonly #emit: (event: PiHostEvent) => void;
  readonly #id: string;
  promptCalls: Array<{ text: string; delivery?: 'steer' | 'followUp' }> = [];
  abortCount = 0;
  disposed = false;
  #thinkingLevel = 'medium';

  constructor(options: { id: string; emit: (event: PiHostEvent) => void }) {
    this.#id = options.id;
    this.#emit = options.emit;
  }

  snapshot(): PiHostSessionSnapshot {
    return {
      id: this.#id,
      cwd: '/workspace/example',
      piSessionId: 'pi-session-id',
      sessionFile: '/tmp/session.jsonl',
      model,
      thinkingLevel: this.#thinkingLevel,
      availableThinkingLevels: ['off', 'low', 'medium', 'high'],
      isStreaming: false,
      isProjectTrusted: false,
    };
  }

  async prompt(options: {
    text: string;
    delivery?: 'steer' | 'followUp';
  }): Promise<boolean> {
    this.promptCalls.push(options);
    this.#emit({ type: 'event', event: 'run.started', sessionId: this.#id });
    this.#emit({
      type: 'event',
      event: 'message.delta',
      sessionId: this.#id,
      data: { delta: 'Hello from Pi' },
    });
    return true;
  }

  async abort(): Promise<void> {
    this.abortCount += 1;
  }

  async listModels(): Promise<PiHostModel[]> {
    return [model];
  }

  async setModel(
    provider: string,
    modelId: string,
  ): Promise<PiHostSessionSnapshot> {
    assert.equal(provider, model.provider);
    assert.equal(modelId, model.id);
    return this.snapshot();
  }

  async setThinkingLevel(level: string): Promise<PiHostSessionSnapshot> {
    this.#thinkingLevel = level;
    return this.snapshot();
  }

  async dispose(): Promise<void> {
    this.disposed = true;
  }
}

class FakeSessionFactory implements PiHostSessionFactory {
  created: FakeSession | undefined;

  async health() {
    return {
      protocolVersion: 1,
      sdkVersion: '0.82.0',
      agentDir: '/mock/.pi/agent',
    };
  }

  async createSession(options: {
    id: string;
    cwd: string;
    tools: string[];
    emit: (event: PiHostEvent) => void;
  }): Promise<PiHostSession> {
    assert.equal(options.cwd, '/workspace/example');
    assert.deepEqual(options.tools, ['read', 'grep', 'find', 'ls']);
    this.created = new FakeSession(options);
    return this.created;
  }
}

async function send(
  server: PiHostServer,
  request: Record<string, unknown>,
): Promise<void> {
  await server.receive(request);
  await server.flush();
}

test('host server creates a session and forwards prompt events', async () => {
  const output = new CaptureWritable();
  const factory = new FakeSessionFactory();
  const server = new PiHostServer({
    factory,
    writer: new JsonlWriter(output),
  });

  await send(server, {
    id: 'create-1',
    method: 'session.create',
    params: { cwd: '/workspace/example' },
  });
  const createResponse = output.records().find((record) => record.id === 'create-1');
  assert.equal(createResponse?.ok, true);
  const sessionId = (
    (createResponse?.result as Record<string, unknown>)?.id
  ) as string;

  await send(server, {
    id: 'prompt-1',
    method: 'session.prompt',
    params: { sessionId, text: 'Explain this repository.' },
  });

  assert.deepEqual(factory.created?.promptCalls, [
    { text: 'Explain this repository.', delivery: undefined },
  ]);
  const records = output.records();
  assert.equal(
    records.some((record) => record.type === 'event' && record.event === 'run.started'),
    true,
  );
  assert.equal(
    records.some((record) => record.type === 'event' && record.event === 'message.delta'),
    true,
  );
  assert.deepEqual(
    records.find((record) => record.id === 'prompt-1')?.result,
    { accepted: true },
  );

  await server.dispose();
  assert.equal(factory.created?.disposed, true);
});

test('host server rejects unsupported tool selection', async () => {
  const output = new CaptureWritable();
  const factory = new FakeSessionFactory();
  const server = new PiHostServer({
    factory,
    writer: new JsonlWriter(output),
  });

  await send(server, {
    id: 'create-invalid-tools',
    method: 'session.create',
    params: {
      cwd: '/workspace/example',
      tools: ['read', 'curl'],
    },
  });

  const response = output.records().find((record) => record.id === 'create-invalid-tools');
  assert.equal(response?.ok, false);
  assert.match(
    ((response?.error as Record<string, unknown>)?.message as string) ?? '',
    /Unsupported Pi tool: curl/,
  );
  assert.equal(factory.created, undefined);
});

test('host server validates delivery and forwards abort/model/thinking commands', async () => {
  const output = new CaptureWritable();
  const factory = new FakeSessionFactory();
  const server = new PiHostServer({
    factory,
    writer: new JsonlWriter(output),
  });

  await send(server, {
    id: 'create-1',
    method: 'session.create',
    params: { cwd: '/workspace/example' },
  });
  const createResponse = output.records().find((record) => record.id === 'create-1');
  const sessionId = (
    (createResponse?.result as Record<string, unknown>)?.id
  ) as string;

  await send(server, {
    id: 'abort-1',
    method: 'session.abort',
    params: { sessionId },
  });
  await send(server, {
    id: 'model-1',
    method: 'session.setModel',
    params: { sessionId, provider: 'openai', modelId: 'gpt-5.4' },
  });
  await send(server, {
    id: 'thinking-1',
    method: 'session.setThinkingLevel',
    params: { sessionId, level: 'high' },
  });
  await send(server, {
    id: 'invalid-prompt',
    method: 'session.prompt',
    params: { sessionId, text: 'Queue this', delivery: 'invalid' },
  });

  assert.equal(factory.created?.abortCount, 1);
  assert.equal(
    ((output.records().find((record) => record.id === 'thinking-1')?.result as Record<string, unknown>)?.thinkingLevel),
    'high',
  );
  assert.equal(
    output.records().find((record) => record.id === 'invalid-prompt')?.ok,
    false,
  );
});
