import { once } from 'node:events';
import { StringDecoder } from 'node:string_decoder';
import type { Readable, Writable } from 'node:stream';

export const protocolVersion = 1;
export const maxJsonlRecordBytes = 1024 * 1024;

export const piHostBuiltinTools = [
  'read',
  'grep',
  'find',
  'ls',
  'bash',
  'edit',
  'write',
] as const;

export type PiHostMethod =
  | 'host.health'
  | 'session.create'
  | 'session.prompt'
  | 'session.abort'
  | 'session.getState'
  | 'session.listModels'
  | 'session.setModel'
  | 'session.setThinkingLevel';

export type PiHostEventName =
  | 'host.error'
  | 'session.created'
  | 'session.state'
  | 'run.started'
  | 'message.delta'
  | 'thinking.delta'
  | 'tool.started'
  | 'tool.updated'
  | 'tool.completed'
  | 'run.settled'
  | 'run.aborted'
  | 'run.failed'
  | 'runtime.diagnostic';

export interface PiHostRequest {
  id: string;
  method: PiHostMethod;
  params?: Record<string, unknown>;
}

export interface PiHostSuccessResponse {
  type: 'response';
  id: string;
  ok: true;
  result: unknown;
}

export interface PiHostErrorResponse {
  type: 'response';
  id: string;
  ok: false;
  error: {
    code: string;
    message: string;
  };
}

export type PiHostResponse = PiHostSuccessResponse | PiHostErrorResponse;

export interface PiHostEvent {
  type: 'event';
  event: PiHostEventName;
  sessionId?: string;
  data?: Record<string, unknown>;
}

export interface PiHostModel {
  provider: string;
  id: string;
  name: string;
  reasoning: boolean;
}

export interface PiHostSessionSnapshot {
  id: string;
  cwd: string;
  piSessionId: string;
  sessionFile: string | null;
  model: PiHostModel | null;
  thinkingLevel: string;
  availableThinkingLevels: string[];
  isStreaming: boolean;
  isProjectTrusted: boolean;
}

export interface PiHostHealth {
  protocolVersion: number;
  sdkVersion: string;
  agentDir: string;
}

export class PiHostProtocolError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'PiHostProtocolError';
  }
}

export type JsonlOutput = Writable | ((line: string) => Promise<void>);

export class JsonlWriter {
  readonly #writeLine: (line: string) => Promise<void>;
  #tail: Promise<void> = Promise.resolve();

  constructor(output: JsonlOutput) {
    if (typeof output === 'function') {
      this.#writeLine = output;
      return;
    }
    this.#writeLine = async (line: string) => {
      if (output.destroyed || !output.writable) {
        throw new PiHostProtocolError('Protocol output stream is not writable.');
      }
      if (!output.write(line)) {
        await once(output, 'drain');
      }
    };
  }

  write(value: PiHostResponse | PiHostEvent): Promise<void> {
    const line = `${JSON.stringify(value)}\n`;
    if (Buffer.byteLength(line, 'utf8') > maxJsonlRecordBytes) {
      throw new PiHostProtocolError('Protocol record exceeds the 1 MiB limit.');
    }
    this.#tail = this.#tail.catch(() => undefined).then(() => this.#writeLine(line));
    return this.#tail;
  }

  flush(): Promise<void> {
    return this.#tail;
  }
}

export async function readJsonl(
  stream: Readable,
  onRecord: (record: unknown) => Promise<void>,
): Promise<void> {
  const decoder = new StringDecoder('utf8');
  let buffer = '';

  const consume = async (line: string): Promise<void> => {
    const normalized = line.endsWith('\r') ? line.slice(0, -1) : line;
    if (normalized.length === 0) {
      return;
    }

    if (Buffer.byteLength(normalized, 'utf8') > maxJsonlRecordBytes) {
      throw new PiHostProtocolError('JSONL record exceeds the 1 MiB protocol limit.');
    }

    try {
      await onRecord(JSON.parse(normalized));
    } catch (error) {
      if (error instanceof PiHostProtocolError) {
        throw error;
      }
      const message = error instanceof Error ? error.message : String(error);
      throw new PiHostProtocolError(`Invalid JSONL record: ${message}`);
    }
  };

  for await (const chunk of stream) {
    const bytes = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk);
    buffer += decoder.write(bytes);

    if (Buffer.byteLength(buffer, 'utf8') > maxJsonlRecordBytes && !buffer.includes('\n')) {
      throw new PiHostProtocolError('JSONL record exceeds the 1 MiB protocol limit.');
    }

    while (true) {
      const newlineIndex = buffer.indexOf('\n');
      if (newlineIndex < 0) {
        break;
      }

      const line = buffer.slice(0, newlineIndex);
      buffer = buffer.slice(newlineIndex + 1);
      await consume(line);
    }
  }

  buffer += decoder.end();
  if (buffer.length > 0) {
    await consume(buffer);
  }
}

export function parsePiHostRequest(value: unknown): PiHostRequest {
  if (!isRecord(value)) {
    throw new PiHostProtocolError('Request must be a JSON object.');
  }

  const id = value.id;
  const method = value.method;
  const params = value.params;

  if (typeof id !== 'string' || id.trim().length === 0) {
    throw new PiHostProtocolError('Request id must be a non-empty string.');
  }
  if (!isPiHostMethod(method)) {
    throw new PiHostProtocolError('Request method is not supported.');
  }
  if (params !== undefined && !isRecord(params)) {
    throw new PiHostProtocolError('Request params must be an object when present.');
  }

  return {
    id,
    method,
    params,
  };
}

export function asRecord(value: unknown, fieldName: string): Record<string, unknown> {
  if (!isRecord(value)) {
    throw new PiHostProtocolError(`${fieldName} must be an object.`);
  }
  return value;
}

export function asNonEmptyString(value: unknown, fieldName: string): string {
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw new PiHostProtocolError(`${fieldName} must be a non-empty string.`);
  }
  return value.trim();
}

export function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function isPiHostMethod(value: unknown): value is PiHostMethod {
  return typeof value === 'string' &&
    [
      'host.health',
      'session.create',
      'session.prompt',
      'session.abort',
      'session.getState',
      'session.listModels',
      'session.setModel',
      'session.setThinkingLevel',
    ].includes(value);
}
