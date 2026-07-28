import { spawn, type ChildProcessWithoutNullStreams } from 'node:child_process';
import { once } from 'node:events';
import { appendFile, mkdir } from 'node:fs/promises';
import { dirname } from 'node:path';
import { StringDecoder } from 'node:string_decoder';

export const piRpcMaxJsonlRecordBytes = 1024 * 1024;
const maxCapturedStderrBytes = 64 * 1024;

export type PiRpcRecordDirection = 'stdin' | 'stdout' | 'lifecycle';

export interface PiRpcRecordedRecord {
  at: string;
  direction: PiRpcRecordDirection;
  sequence: number;
  value: Record<string, unknown>;
}

export interface PiRpcExitInfo {
  code: number | null;
  signal: NodeJS.Signals | null;
}

export interface PiRpcHarnessOptions {
  args: string[];
  cwd: string;
  executable: string;
  env?: NodeJS.ProcessEnv;
  recordFile?: string;
  timeoutMs?: number;
}

export interface PiRpcWaitOptions {
  fromIndex?: number;
  timeoutMs?: number;
}

export class PiRpcHarnessError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'PiRpcHarnessError';
  }
}

export class StrictPiRpcJsonlDecoder {
  #buffer = '';
  readonly #decoder = new StringDecoder('utf8');

  push(chunk: Buffer | string): Record<string, unknown>[] {
    const bytes = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk, 'utf8');
    this.#buffer += this.#decoder.write(bytes);
    return this.#drainCompleteRecords();
  }

  finish(): Record<string, unknown>[] {
    this.#buffer += this.#decoder.end();
    if (this.#buffer.length > 0) {
      throw new PiRpcHarnessError('Pi RPC stdout ended with an unterminated JSONL record.');
    }
    return [];
  }

  #drainCompleteRecords(): Record<string, unknown>[] {
    if (
      Buffer.byteLength(this.#buffer, 'utf8') > piRpcMaxJsonlRecordBytes &&
      !this.#buffer.includes('\n')
    ) {
      throw new PiRpcHarnessError('Pi RPC JSONL record exceeds the 1 MiB limit.');
    }

    const records: Record<string, unknown>[] = [];
    while (true) {
      const newlineIndex = this.#buffer.indexOf('\n');
      if (newlineIndex < 0) {
        break;
      }

      const rawLine = this.#buffer.slice(0, newlineIndex);
      this.#buffer = this.#buffer.slice(newlineIndex + 1);
      const line = rawLine.endsWith('\r') ? rawLine.slice(0, -1) : rawLine;
      if (line.length === 0) {
        continue;
      }
      if (Buffer.byteLength(line, 'utf8') > piRpcMaxJsonlRecordBytes) {
        throw new PiRpcHarnessError('Pi RPC JSONL record exceeds the 1 MiB limit.');
      }

      let value: unknown;
      try {
        value = JSON.parse(line);
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        throw new PiRpcHarnessError(`Pi RPC emitted invalid JSONL: ${message}`);
      }
      if (!isRecord(value)) {
        throw new PiRpcHarnessError('Pi RPC emitted a JSONL value that is not an object.');
      }
      records.push(value);
    }

    return records;
  }
}

interface PiRpcWaiter {
  description: string;
  fromIndex: number;
  predicate: (record: PiRpcRecordedRecord) => boolean;
  reject: (error: Error) => void;
  resolve: (record: PiRpcRecordedRecord) => void;
  timer: NodeJS.Timeout;
}

export class PiRpcHarness {
  readonly #child: ChildProcessWithoutNullStreams;
  readonly #decoder = new StrictPiRpcJsonlDecoder();
  readonly #defaultTimeoutMs: number;
  readonly #recordFile: string | undefined;
  readonly #records: PiRpcRecordedRecord[] = [];
  readonly #waiters = new Set<PiRpcWaiter>();
  readonly #exitPromise: Promise<PiRpcExitInfo>;
  #exitInfo: PiRpcExitInfo | undefined;
  #failure: Error | undefined;
  #recordTail: Promise<void> = Promise.resolve();
  #sequence = 0;
  #stderr = '';
  #resolveExit!: (info: PiRpcExitInfo) => void;

  private constructor(child: ChildProcessWithoutNullStreams, options: PiRpcHarnessOptions) {
    this.#child = child;
    this.#defaultTimeoutMs = options.timeoutMs ?? 20_000;
    this.#recordFile = options.recordFile;
    this.#exitPromise = new Promise<PiRpcExitInfo>((resolve) => {
      this.#resolveExit = resolve;
    });

    child.stdout.on('data', (chunk: Buffer) => {
      try {
        for (const value of this.#decoder.push(chunk)) {
          this.#record('stdout', value);
        }
      } catch (error) {
        this.#fail(toHarnessError(error));
        child.kill('SIGTERM');
      }
    });
    child.stderr.on('data', (chunk: Buffer) => {
      this.#stderr = `${this.#stderr}${chunk.toString('utf8')}`.slice(-maxCapturedStderrBytes);
    });
    child.once('error', (error) => {
      this.#fail(new PiRpcHarnessError(`Unable to start Pi RPC process: ${error.message}`));
    });
    child.once('close', (code, signal) => {
      try {
        for (const value of this.#decoder.finish()) {
          this.#record('stdout', value);
        }
      } catch (error) {
        this.#fail(toHarnessError(error));
      }

      const exitInfo: PiRpcExitInfo = { code, signal };
      this.#exitInfo = exitInfo;
      this.#record('lifecycle', {
        type: 'process_exit',
        code,
        signal,
      });
      this.#resolveExit(exitInfo);
      this.#rejectWaiters(
        this.#failure ??
          new PiRpcHarnessError(
            `Pi RPC process exited before the expected record (${formatExitInfo(exitInfo)}).`,
          ),
      );
    });
  }

  static async start(options: PiRpcHarnessOptions): Promise<PiRpcHarness> {
    if (options.recordFile !== undefined) {
      await mkdir(dirname(options.recordFile), { recursive: true });
    }

    const child = spawn(options.executable, options.args, {
      cwd: options.cwd,
      env: { ...process.env, ...options.env },
      stdio: ['pipe', 'pipe', 'pipe'],
    });
    return new PiRpcHarness(child, options);
  }

  get exitInfo(): PiRpcExitInfo | undefined {
    return this.#exitInfo;
  }

  get recordCount(): number {
    return this.#records.length;
  }

  get records(): readonly PiRpcRecordedRecord[] {
    return this.#records;
  }

  get stderr(): string {
    return this.#stderr;
  }

  async send(command: Record<string, unknown>): Promise<void> {
    this.#throwIfUnavailable();
    const line = `${JSON.stringify(command)}\n`;
    if (Buffer.byteLength(line, 'utf8') > piRpcMaxJsonlRecordBytes) {
      throw new PiRpcHarnessError('Pi RPC request exceeds the 1 MiB JSONL limit.');
    }

    this.#record('stdin', command);
    if (!this.#child.stdin.write(line)) {
      await once(this.#child.stdin, 'drain');
    }
  }

  async request(
    command: Record<string, unknown> & { id: string },
    options: PiRpcWaitOptions = {},
  ): Promise<Record<string, unknown>> {
    const response = this.waitFor(
      (record) =>
        record.direction === 'stdout' &&
        record.value.type === 'response' &&
        record.value.id === command.id,
      `response for ${command.id}`,
      options,
    );
    await this.send(command);
    return (await response).value;
  }

  async waitFor(
    predicate: (record: PiRpcRecordedRecord) => boolean,
    description: string,
    options: PiRpcWaitOptions = {},
  ): Promise<PiRpcRecordedRecord> {
    const fromIndex = options.fromIndex ?? 0;
    const existing = this.#records.slice(fromIndex).find(predicate);
    if (existing !== undefined) {
      return existing;
    }
    this.#throwIfUnavailable();

    const timeoutMs = options.timeoutMs ?? this.#defaultTimeoutMs;
    return new Promise<PiRpcRecordedRecord>((resolve, reject) => {
      const waiter: PiRpcWaiter = {
        description,
        fromIndex,
        predicate,
        resolve: (record) => {
          clearTimeout(waiter.timer);
          this.#waiters.delete(waiter);
          resolve(record);
        },
        reject: (error) => {
          clearTimeout(waiter.timer);
          this.#waiters.delete(waiter);
          reject(error);
        },
        timer: setTimeout(() => {
          waiter.reject(
            new PiRpcHarnessError(
              `Timed out after ${timeoutMs}ms while waiting for ${description}.${this.#stderrSuffix()}`,
            ),
          );
        }, timeoutMs),
      };
      this.#waiters.add(waiter);
    });
  }

  async flush(): Promise<void> {
    await this.#recordTail;
  }

  async close(graceMs = 1_000): Promise<PiRpcExitInfo> {
    if (this.#exitInfo !== undefined) {
      await this.flush();
      return this.#exitInfo;
    }

    this.#child.stdin.end();
    try {
      const exitInfo = await this.#waitForExit(graceMs);
      await this.flush();
      return exitInfo;
    } catch {
      return this.terminate();
    }
  }

  async terminate(graceMs = 2_000): Promise<PiRpcExitInfo> {
    if (this.#exitInfo !== undefined) {
      await this.flush();
      return this.#exitInfo;
    }

    this.#child.kill('SIGTERM');
    try {
      const exitInfo = await this.#waitForExit(graceMs);
      await this.flush();
      return exitInfo;
    } catch {
      this.#child.kill('SIGKILL');
      const exitInfo = await this.#waitForExit(graceMs);
      await this.flush();
      return exitInfo;
    }
  }

  #record(direction: PiRpcRecordDirection, value: Record<string, unknown>): void {
    const record: PiRpcRecordedRecord = {
      at: new Date().toISOString(),
      direction,
      sequence: this.#sequence++,
      value,
    };
    this.#records.push(record);
    if (this.#recordFile !== undefined) {
      const line = `${JSON.stringify(record)}\n`;
      this.#recordTail = this.#recordTail.then(() => appendFile(this.#recordFile!, line, 'utf8'));
      this.#recordTail.catch((error: unknown) => {
        this.#fail(new PiRpcHarnessError(`Unable to write Pi RPC recording: ${String(error)}`));
      });
    }

    for (const waiter of [...this.#waiters]) {
      if (record.sequence >= waiter.fromIndex && waiter.predicate(record)) {
        waiter.resolve(record);
      }
    }
  }

  #throwIfUnavailable(): void {
    if (this.#failure !== undefined) {
      throw this.#failure;
    }
    if (this.#exitInfo !== undefined) {
      throw new PiRpcHarnessError(
        `Pi RPC process is no longer available (${formatExitInfo(this.#exitInfo)}).`,
      );
    }
  }

  #fail(error: Error): void {
    if (this.#failure !== undefined) {
      return;
    }
    this.#failure = error;
    this.#rejectWaiters(error);
  }

  #rejectWaiters(error: Error): void {
    for (const waiter of [...this.#waiters]) {
      waiter.reject(error);
    }
  }

  async #waitForExit(timeoutMs: number): Promise<PiRpcExitInfo> {
    if (this.#exitInfo !== undefined) {
      return this.#exitInfo;
    }
    return new Promise<PiRpcExitInfo>((resolve, reject) => {
      const timer = setTimeout(() => {
        reject(new PiRpcHarnessError(`Timed out after ${timeoutMs}ms waiting for Pi RPC process exit.`));
      }, timeoutMs);
      this.#exitPromise.then((info) => {
        clearTimeout(timer);
        resolve(info);
      });
    });
  }

  #stderrSuffix(): string {
    return this.#stderr.length === 0 ? '' : ` stderr: ${this.#stderr}`;
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function formatExitInfo(exitInfo: PiRpcExitInfo): string {
  return exitInfo.signal === null
    ? `exit code ${exitInfo.code ?? 'unknown'}`
    : `signal ${exitInfo.signal}`;
}

function toHarnessError(error: unknown): PiRpcHarnessError {
  return error instanceof PiRpcHarnessError
    ? error
    : new PiRpcHarnessError(error instanceof Error ? error.message : String(error));
}
