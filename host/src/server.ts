import { randomUUID } from 'node:crypto';
import type { Readable } from 'node:stream';

import {
  asNonEmptyString,
  isRecord,
  JsonlWriter,
  parsePiHostRequest,
  piHostBuiltinTools,
  PiHostProtocolError,
  readJsonl,
  type PiHostEvent,
  type PiHostHealth,
  type PiHostMethod,
  type PiHostModel,
  type PiHostRequest,
  type PiHostSessionSnapshot,
} from './protocol.js';

export interface PiHostSession {
  snapshot(): PiHostSessionSnapshot;
  prompt(options: {
    text: string;
    delivery?: 'steer' | 'followUp';
  }): Promise<boolean>;
  abort(): Promise<void>;
  listModels(): Promise<PiHostModel[]>;
  setModel(provider: string, modelId: string): Promise<PiHostSessionSnapshot>;
  setThinkingLevel(level: string): Promise<PiHostSessionSnapshot>;
  dispose(): Promise<void>;
}

export interface PiHostSessionFactory {
  health(): Promise<PiHostHealth>;
  createSession(options: {
    id: string;
    cwd: string;
    tools: string[];
    emit: (event: PiHostEvent) => void;
  }): Promise<PiHostSession>;
}

export class PiHostServer {
  readonly #factory: PiHostSessionFactory;
  readonly #writer: JsonlWriter;
  readonly #sessions = new Map<string, PiHostSession>();
  #requestTail: Promise<void> = Promise.resolve();

  constructor(options: { factory: PiHostSessionFactory; writer: JsonlWriter }) {
    this.#factory = options.factory;
    this.#writer = options.writer;
  }

  async run(input: Readable): Promise<void> {
    await readJsonl(input, async (record) => {
      await this.receive(record);
    });
  }

  receive(record: unknown): Promise<void> {
    this.#requestTail = this.#requestTail
      .catch(() => undefined)
      .then(() => this.#handleRecord(record));
    return this.#requestTail;
  }

  async dispose(): Promise<void> {
    const sessions = [...this.#sessions.values()];
    this.#sessions.clear();
    await Promise.allSettled(sessions.map((session) => session.dispose()));
    await this.#writer.flush();
  }

  flush(): Promise<void> {
    return this.#writer.flush();
  }

  async #handleRecord(record: unknown): Promise<void> {
    let request: PiHostRequest;
    try {
      request = parsePiHostRequest(record);
    } catch (error) {
      const id = isRecord(record) && typeof record.id === 'string'
        ? record.id
        : undefined;
      const message = messageFor(error);
      if (id !== undefined) {
        await this.#writeFailure(id, 'invalid_request', message);
      } else {
        await this.#writer.write({
          type: 'event',
          event: 'host.error',
          data: { code: 'invalid_request', message },
        });
      }
      return;
    }

    try {
      const result = await this.#dispatch(request.method, request.params ?? {});
      await this.#writer.write({
        type: 'response',
        id: request.id,
        ok: true,
        result,
      });
    } catch (error) {
      const protocolError = error instanceof PiHostProtocolError;
      await this.#writeFailure(
        request.id,
        protocolError ? 'invalid_request' : 'operation_failed',
        messageFor(error),
      );
    }
  }

  async #dispatch(
    method: PiHostMethod,
    params: Record<string, unknown>,
  ): Promise<unknown> {
    switch (method) {
      case 'host.health':
        return this.#factory.health();
      case 'session.create':
        return this.#createSession(params);
      case 'session.prompt':
        return this.#prompt(params);
      case 'session.abort':
        return this.#abort(params);
      case 'session.getState':
        return this.#sessionForParams(params).snapshot();
      case 'session.listModels':
        return this.#listModels(params);
      case 'session.setModel':
        return this.#setModel(params);
      case 'session.setThinkingLevel':
        return this.#setThinkingLevel(params);
    }
  }

  async #createSession(params: Record<string, unknown>): Promise<PiHostSessionSnapshot> {
    const cwd = asNonEmptyString(params.cwd, 'cwd');
    const tools = toolsFor(params.tools);
    const id = randomUUID();
    const session = await this.#factory.createSession({
      id,
      cwd,
      tools,
      emit: (event) => {
        this.#writeEvent(event);
      },
    });
    this.#sessions.set(id, session);
    const snapshot = session.snapshot();
    await this.#writer.write({
      type: 'event',
      event: 'session.created',
      sessionId: snapshot.id,
      data: { session: snapshot },
    });
    return snapshot;
  }

  async #prompt(params: Record<string, unknown>): Promise<{ accepted: boolean }> {
    const session = this.#sessionForParams(params);
    const text = asNonEmptyString(params.text, 'text');
    const delivery = optionalDelivery(params.delivery);
    const accepted = await session.prompt({ text, delivery });
    return { accepted };
  }

  async #abort(params: Record<string, unknown>): Promise<PiHostSessionSnapshot> {
    const session = this.#sessionForParams(params);
    await session.abort();
    return session.snapshot();
  }

  async #listModels(params: Record<string, unknown>): Promise<{ models: PiHostModel[] }> {
    const session = this.#sessionForParams(params);
    return { models: await session.listModels() };
  }

  async #setModel(params: Record<string, unknown>): Promise<PiHostSessionSnapshot> {
    const session = this.#sessionForParams(params);
    const provider = asNonEmptyString(params.provider, 'provider');
    const modelId = asNonEmptyString(params.modelId, 'modelId');
    return session.setModel(provider, modelId);
  }

  async #setThinkingLevel(
    params: Record<string, unknown>,
  ): Promise<PiHostSessionSnapshot> {
    const session = this.#sessionForParams(params);
    return session.setThinkingLevel(asNonEmptyString(params.level, 'level'));
  }

  #sessionForParams(params: Record<string, unknown>): PiHostSession {
    const sessionId = asNonEmptyString(params.sessionId, 'sessionId');
    const session = this.#sessions.get(sessionId);
    if (session === undefined) {
      throw new PiHostProtocolError(`Unknown session: ${sessionId}`);
    }
    return session;
  }

  #writeEvent(event: PiHostEvent): void {
    try {
      void this.#writer.write(event).catch((error: unknown) => {
        this.#writeOutputFailure(error);
      });
    } catch (error) {
      this.#writeOutputFailure(error);
    }
  }

  #writeOutputFailure(error: unknown): void {
    const message = `Failed to write Pi host event: ${messageFor(error)}`;
    try {
      void this.#writer
          .write({
            type: 'event',
            event: 'host.error',
            data: { code: 'protocol_output_failed', message },
          })
          .catch(() => {
            process.stderr.write(`[pi-host] ${message}\n`);
          });
    } catch (_) {
      process.stderr.write(`[pi-host] ${message}\n`);
    }
  }

  #writeFailure(id: string, code: string, message: string): Promise<void> {
    return this.#writer.write({
      type: 'response',
      id,
      ok: false,
      error: { code, message },
    });
  }
}

function toolsFor(value: unknown): string[] {
  if (value === undefined) {
    return ['read', 'grep', 'find', 'ls'];
  }
  if (!Array.isArray(value)) {
    throw new PiHostProtocolError('tools must be an array when present.');
  }

  for (const tool of value) {
    if (
      typeof tool !== 'string' ||
      !piHostBuiltinTools.includes(
        tool as (typeof piHostBuiltinTools)[number],
      )
    ) {
      throw new PiHostProtocolError(`Unsupported Pi tool: ${String(tool)}`);
    }
  }
  return [...new Set(value as string[])];
}

function optionalDelivery(value: unknown): 'steer' | 'followUp' | undefined {
  if (value === undefined) {
    return undefined;
  }
  if (value === 'steer' || value === 'followUp') {
    return value;
  }
  throw new PiHostProtocolError('delivery must be "steer" or "followUp".');
}

function messageFor(error: unknown): string {
  if (error instanceof Error && error.message.trim().length > 0) {
    return error.message;
  }
  return String(error);
}
