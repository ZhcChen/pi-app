import { realpath, stat } from 'node:fs/promises';
import { join } from 'node:path';

import {
  createAgentSessionFromServices,
  createAgentSessionRuntime,
  createAgentSessionServices,
  getAgentDir,
  ModelRuntime,
  SessionManager,
  SettingsManager,
  VERSION,
  type AgentSession,
  type AgentSessionEvent,
  type AgentSessionRuntime,
} from '@earendil-works/pi-coding-agent';

import {
  maxJsonlRecordBytes,
  type PiHostEvent,
  type PiHostHealth,
  type PiHostModel,
  type PiHostSessionSnapshot,
} from './protocol.js';
import type { PiHostSession, PiHostSessionFactory } from './server.js';

export class PiSdkSessionFactory implements PiHostSessionFactory {
  readonly #agentDir: string;
  #modelRuntimePromise: Promise<ModelRuntime> | undefined;

  constructor(options: { agentDir?: string } = {}) {
    this.#agentDir = options.agentDir ?? getAgentDir();
  }

  async health(): Promise<PiHostHealth> {
    return {
      protocolVersion: 1,
      sdkVersion: VERSION,
      agentDir: this.#agentDir,
    };
  }

  async createSession(options: {
    id: string;
    cwd: string;
    tools: string[];
    emit: (event: PiHostEvent) => void;
  }): Promise<PiHostSession> {
    const cwd = await resolveExistingDirectory(options.cwd);
    const session = new PiSdkSession({
      id: options.id,
      cwd,
      agentDir: this.#agentDir,
      tools: options.tools,
      modelRuntime: this.#modelRuntime(),
      emit: options.emit,
    });
    await session.initialize();
    return session;
  }

  #modelRuntime(): Promise<ModelRuntime> {
    this.#modelRuntimePromise ??= ModelRuntime.create({
      authPath: join(this.#agentDir, 'auth.json'),
      modelsPath: join(this.#agentDir, 'models.json'),
    });
    return this.#modelRuntimePromise;
  }
}

class PiSdkSession implements PiHostSession {
  readonly #id: string;
  readonly #cwd: string;
  readonly #agentDir: string;
  readonly #tools: string[];
  readonly #modelRuntime: Promise<ModelRuntime>;
  readonly #emit: (event: PiHostEvent) => void;

  #runtime: AgentSessionRuntime | undefined;
  #unsubscribe: (() => void) | undefined;
  #activePrompt: Promise<void> | undefined;
  #onPromptAgentStart: (() => void) | undefined;

  constructor(options: {
    id: string;
    cwd: string;
    agentDir: string;
    tools: string[];
    modelRuntime: Promise<ModelRuntime>;
    emit: (event: PiHostEvent) => void;
  }) {
    this.#id = options.id;
    this.#cwd = options.cwd;
    this.#agentDir = options.agentDir;
    this.#tools = options.tools;
    this.#modelRuntime = options.modelRuntime;
    this.#emit = options.emit;
  }

  async initialize(): Promise<void> {
    const modelRuntime = await this.#modelRuntime;
    const createRuntime = async ({
      cwd,
      agentDir,
      sessionManager,
      sessionStartEvent,
    }: {
      cwd: string;
      agentDir: string;
      sessionManager: SessionManager;
      sessionStartEvent?: { type: 'session_start'; reason: 'startup' | 'reload' | 'new' | 'resume' | 'fork'; previousSessionFile?: string };
    }) => {
      // The first GUI slice does not silently trust project-local executable resources.
      const settingsManager = SettingsManager.create(cwd, agentDir, {
        projectTrusted: false,
      });
      const services = await createAgentSessionServices({
        cwd,
        agentDir,
        modelRuntime,
        settingsManager,
      });
      const created = await createAgentSessionFromServices({
        services,
        sessionManager,
        sessionStartEvent,
        tools: this.#tools,
      });

      return {
        ...created,
        services,
        diagnostics: services.diagnostics,
      };
    };

    const sessionManager = SessionManager.create(this.#cwd);
    const runtime = await createAgentSessionRuntime(createRuntime, {
      cwd: this.#cwd,
      agentDir: this.#agentDir,
      sessionManager,
    });
    this.#runtime = runtime;
    runtime.setRebindSession(async (session) => this.#bindSession(session));
    await this.#bindSession(runtime.session);

    for (const diagnostic of runtime.diagnostics) {
      this.#emit({
        type: 'event',
        event: 'runtime.diagnostic',
        sessionId: this.#id,
        data: {
          type: diagnostic.type,
          message: diagnostic.message,
        },
      });
    }

    if (runtime.modelFallbackMessage !== undefined) {
      this.#emit({
        type: 'event',
        event: 'runtime.diagnostic',
        sessionId: this.#id,
        data: { type: 'warning', message: runtime.modelFallbackMessage },
      });
    }
  }

  snapshot(): PiHostSessionSnapshot {
    const runtime = this.#requireRuntime();
    const session = runtime.session;
    return {
      id: this.#id,
      cwd: runtime.cwd,
      piSessionId: session.sessionId,
      sessionFile: session.sessionFile ?? null,
      model: modelFor(session.model),
      thinkingLevel: session.thinkingLevel,
      availableThinkingLevels: [...session.getAvailableThinkingLevels()],
      isStreaming: session.isStreaming,
      isProjectTrusted: runtime.services.settingsManager.isProjectTrusted(),
    };
  }

  async prompt(options: {
    text: string;
    delivery?: 'steer' | 'followUp';
  }): Promise<boolean> {
    const session = this.#requireRuntime().session;
    const wasStreaming = session.isStreaming;
    let preflightSettled = false;
    let resolvePreflight: (accepted: boolean) => void;
    let rejectPreflight: (error: Error) => void;
    const preflight = new Promise<boolean>((resolve, reject) => {
      resolvePreflight = resolve;
      rejectPreflight = reject;
    });
    let resolveLifecycle: () => void = () => {};
    const lifecycle = new Promise<void>((resolve) => {
      resolveLifecycle = resolve;
    });
    let agentStarted = false;
    if (!wasStreaming) {
      this.#onPromptAgentStart = () => {
        agentStarted = true;
        this.#onPromptAgentStart = undefined;
        resolveLifecycle();
      };
    }

    const completion = session.prompt(options.text, {
      source: 'rpc',
      streamingBehavior: options.delivery,
      preflightResult: (accepted) => {
        if (!preflightSettled) {
          preflightSettled = true;
          resolvePreflight(accepted);
        }
      },
    });
    this.#activePrompt = completion;

    void completion
      .then(
        () => {
          if (!wasStreaming && !agentStarted) {
            this.#onPromptAgentStart = undefined;
            this.#emit({
              type: 'event',
              event: 'run.settled',
              sessionId: this.#id,
              data: {
                session: this.snapshot(),
                handledWithoutRun: true,
              },
            });
            resolveLifecycle();
          }
        },
        (error: unknown) => {
          const normalized = errorFor(error);
          if (!preflightSettled) {
            preflightSettled = true;
            rejectPreflight(normalized);
            return;
          }
          this.#emitRunFailure(normalized.message);
          if (!wasStreaming && !agentStarted) {
            this.#onPromptAgentStart = undefined;
            resolveLifecycle();
          }
        },
      )
      .finally(() => {
        if (this.#activePrompt === completion) {
          this.#activePrompt = undefined;
        }
      });

    const accepted = await preflight;
    if (!accepted || wasStreaming) {
      return accepted;
    }

    await lifecycle;
    return true;
  }

  async abort(): Promise<void> {
    await this.#requireRuntime().session.abort();
    this.#emitState();
  }

  async listModels(): Promise<PiHostModel[]> {
    const models = await this.#requireRuntime().services.modelRuntime.getAvailable();
    return models.map(modelFor).filter((model): model is PiHostModel => model !== null);
  }

  async setModel(
    provider: string,
    modelId: string,
  ): Promise<PiHostSessionSnapshot> {
    const runtime = this.#requireRuntime();
    if (!runtime.session.isIdle) {
      throw new Error('Cannot change the model while the session is running.');
    }

    const model = runtime.services.modelRuntime.getModel(provider, modelId);
    if (model === undefined) {
      throw new Error(`Unknown Pi model: ${provider}/${modelId}`);
    }
    await runtime.session.setModel(model);
    this.#emitState();
    return this.snapshot();
  }

  async setThinkingLevel(level: string): Promise<PiHostSessionSnapshot> {
    const runtime = this.#requireRuntime();
    if (!runtime.session.isIdle) {
      throw new Error('Cannot change thinking level while the session is running.');
    }

    runtime.session.setThinkingLevel(level as never);
    this.#emitState();
    return this.snapshot();
  }

  async dispose(): Promise<void> {
    const runtime = this.#runtime;
    if (runtime === undefined) {
      return;
    }

    try {
      await runtime.session.abort();
    } catch (_) {}
    this.#unsubscribe?.();
    this.#unsubscribe = undefined;
    await runtime.dispose();
    this.#runtime = undefined;
  }

  async #bindSession(session: AgentSession): Promise<void> {
    this.#unsubscribe?.();
    this.#unsubscribe = session.subscribe((event) => this.#handleSessionEvent(event));
    await session.bindExtensions({
      mode: 'json',
      onError: (error) => {
        this.#emit({
          type: 'event',
          event: 'runtime.diagnostic',
          sessionId: this.#id,
          data: {
            type: 'error',
            message: `Extension ${error.extensionPath} ${error.event}: ${error.error}`,
          },
        });
      },
    });
  }

  #handleSessionEvent(event: AgentSessionEvent): void {
    switch (event.type) {
      case 'agent_start':
        this.#onPromptAgentStart?.();
        this.#emit({
          type: 'event',
          event: 'run.started',
          sessionId: this.#id,
        });
        break;
      case 'agent_settled':
        this.#emit({
          type: 'event',
          event: 'run.settled',
          sessionId: this.#id,
          data: { session: this.snapshot() },
        });
        break;
      case 'message_update':
        this.#handleMessageUpdate(event);
        break;
      case 'tool_execution_start':
        this.#emit({
          type: 'event',
          event: 'tool.started',
          sessionId: this.#id,
          data: {
            toolCallId: event.toolCallId,
            toolName: event.toolName,
          },
        });
        break;
      case 'tool_execution_update':
        this.#emit({
          type: 'event',
          event: 'tool.updated',
          sessionId: this.#id,
          data: {
            toolCallId: event.toolCallId,
            toolName: event.toolName,
          },
        });
        break;
      case 'tool_execution_end':
        this.#emit({
          type: 'event',
          event: 'tool.completed',
          sessionId: this.#id,
          data: {
            toolCallId: event.toolCallId,
            toolName: event.toolName,
            isError: event.isError,
          },
        });
        if (event.isError) {
          this.#emitRunFailure(`Tool failed: ${event.toolName}`);
        }
        break;
      case 'thinking_level_changed':
      case 'session_info_changed':
        this.#emitState();
        break;
      case 'compaction_end':
        if (event.errorMessage !== undefined) {
          this.#emitRunFailure(event.errorMessage);
        }
        break;
      case 'auto_retry_end':
        if (!event.success && event.finalError !== undefined) {
          this.#emitRunFailure(event.finalError);
        }
        break;
      default:
        break;
    }
  }

  #handleMessageUpdate(event: Extract<AgentSessionEvent, { type: 'message_update' }>): void {
    const update = event.assistantMessageEvent;
    if (update.type === 'text_delta') {
      for (const delta of protocolTextChunks(update.delta)) {
        this.#emit({
          type: 'event',
          event: 'message.delta',
          sessionId: this.#id,
          data: { delta },
        });
      }
      return;
    }
    if (update.type === 'thinking_delta') {
      for (const delta of protocolTextChunks(update.delta)) {
        this.#emit({
          type: 'event',
          event: 'thinking.delta',
          sessionId: this.#id,
          data: { delta },
        });
      }
      return;
    }
    if (update.type === 'error') {
      if (update.reason === 'aborted') {
        this.#emit({
          type: 'event',
          event: 'run.aborted',
          sessionId: this.#id,
        });
      } else {
        this.#emitRunFailure(update.reason);
      }
    }
  }

  #emitState(): void {
    this.#emit({
      type: 'event',
      event: 'session.state',
      sessionId: this.#id,
      data: { session: this.snapshot() },
    });
  }

  #emitRunFailure(message: string): void {
    this.#emit({
      type: 'event',
      event: 'run.failed',
      sessionId: this.#id,
      data: { message },
    });
  }

  #requireRuntime(): AgentSessionRuntime {
    if (this.#runtime === undefined) {
      throw new Error('Pi session has not been initialized.');
    }
    return this.#runtime;
  }
}

function modelFor(model: AgentSession['model']): PiHostModel | null {
  if (model === undefined) {
    return null;
  }
  return {
    provider: model.provider,
    id: model.id,
    name: model.name ?? model.id,
    reasoning: model.reasoning === true,
  };
}

async function resolveExistingDirectory(path: string): Promise<string> {
  const resolved = await realpath(path);
  const metadata = await stat(resolved);
  if (!metadata.isDirectory()) {
    throw new Error(`Session cwd is not a directory: ${path}`);
  }
  return resolved;
}

function protocolTextChunks(text: string): string[] {
  const maxChunkBytes = Math.floor(maxJsonlRecordBytes / 4);
  if (Buffer.byteLength(text, 'utf8') <= maxChunkBytes) {
    return [text];
  }

  const chunks: string[] = [];
  let chunk = '';
  let chunkBytes = 0;
  for (const character of text) {
    const characterBytes = Buffer.byteLength(character, 'utf8');
    if (chunkBytes + characterBytes > maxChunkBytes && chunk.length > 0) {
      chunks.push(chunk);
      chunk = '';
      chunkBytes = 0;
    }
    chunk += character;
    chunkBytes += characterBytes;
  }
  if (chunk.length > 0) {
    chunks.push(chunk);
  }
  return chunks;
}

function errorFor(error: unknown): Error {
  if (error instanceof Error) {
    return error;
  }
  return new Error(String(error));
}
