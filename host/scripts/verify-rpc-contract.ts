import assert from 'node:assert/strict';
import { execFile as execFileCallback } from 'node:child_process';
import { cp, mkdtemp, mkdir, stat, writeFile } from 'node:fs/promises';
import { promisify } from 'node:util';
import { tmpdir } from 'node:os';
import { isAbsolute, join, relative, resolve } from 'node:path';

import {
  PiRpcHarness,
  PiRpcHarnessError,
  type PiRpcRecordedRecord,
} from '../src/pi_rpc_harness.js';

const execFile = promisify(execFileCallback);
const builtinTools = ['read', 'grep', 'find', 'ls', 'bash', 'edit', 'write'];
const projectCommandNames = [
  'pi-app-rpc-project-probe',
  'pi-app-rpc-project-template',
  'skill:pi-app-rpc-project-skill',
];

interface VerifyOptions {
  outputDir?: string;
  piExecutable: string;
  timeoutMs: number;
}

interface ContractReport {
  generatedAt: string;
  outputDir: string;
  pi: {
    executable: string;
    version: string;
  };
  scenarios: Record<string, Record<string, unknown>>;
}

const activeHarnesses = new Set<PiRpcHarness>();

async function main(): Promise<void> {
  const options = parseOptions(process.argv.slice(2));
  const outputDir = options.outputDir === undefined
    ? await mkdtemp(join(tmpdir(), 'pi-app-rpc-contract-'))
    : resolve(options.outputDir);
  ensureOutputOutsideRepository(outputDir);
  await mkdir(outputDir, { recursive: true });

  const report: ContractReport = {
    generatedAt: new Date().toISOString(),
    outputDir,
    pi: {
      executable: options.piExecutable,
      version: await readPiVersion(options.piExecutable),
    },
    scenarios: {},
  };

  try {
    report.scenarios.sessionAndState = await verifySessionAndState(outputDir, options);
    report.scenarios.projectTrust = await verifyProjectTrust(outputDir, options);
    report.scenarios.liveAgent = await verifyLiveAgent(outputDir, options);
    report.scenarios.queueControls = await verifyQueueControls(outputDir, options);
    report.scenarios.processExit = await verifyProcessExit(outputDir, options);

    await writeJson(join(outputDir, 'report.json'), report);
    process.stdout.write(`${JSON.stringify({ outputDir, report })}\n`);
  } catch (error) {
    const message = error instanceof Error ? error.stack ?? error.message : String(error);
    await writeJson(join(outputDir, 'failure.json'), {
      generatedAt: new Date().toISOString(),
      error: message,
      report,
    });
    process.stderr.write(`Pi RPC contract verification failed. Evidence: ${outputDir}\n${message}\n`);
    process.exitCode = 1;
  } finally {
    await Promise.all([...activeHarnesses].map(async (harness) => {
      try {
        await harness.terminate();
      } catch {
        // The primary verification error and its recordings are more useful here.
      }
    }));
  }
}

async function verifySessionAndState(
  outputDir: string,
  options: VerifyOptions,
): Promise<Record<string, unknown>> {
  const sessionDir = join(outputDir, 'sessions');
  const cwd = join(outputDir, 'session-workspace');
  await mkdir(cwd, { recursive: true });

  const first = await startPi('session-create', cwd, outputDir, options, [
    '--session-dir',
    sessionDir,
    '--no-approve',
    '--no-tools',
    '--no-extensions',
    '--no-skills',
    '--no-prompt-templates',
    '--no-context-files',
  ]);
  try {
    const initialState = responseData(await first.request({
      id: 'state-initial',
      type: 'get_state',
    }));
    const model = requiredRecord(initialState.model, 'get_state.data.model');
    const sessionFile = requiredString(initialState.sessionFile, 'get_state.data.sessionFile');
    const sessionId = requiredString(initialState.sessionId, 'get_state.data.sessionId');

    const models = responseData(await first.request({
      id: 'models-initial',
      type: 'get_available_models',
    }));
    const availableModels = requiredArray(models.models, 'get_available_models.data.models');
    assert.equal(
      availableModels.some((entry) => isRecord(entry) && entry.id === model.id),
      true,
      'Current model must be present in get_available_models.',
    );

    const thinking = responseData(await first.request({
      id: 'thinking-levels',
      type: 'get_available_thinking_levels',
    }));
    const availableThinkingLevels = requiredArray(
      thinking.levels,
      'get_available_thinking_levels.data.levels',
    );
    const thinkingLevel = requiredString(initialState.thinkingLevel, 'get_state.data.thinkingLevel');
    assert.equal(availableThinkingLevels.includes(thinkingLevel), true);

    responseData(await first.request({
      id: 'set-model-current',
      type: 'set_model',
      provider: requiredString(model.provider, 'get_state.data.model.provider'),
      modelId: requiredString(model.id, 'get_state.data.model.id'),
    }));
    expectSuccess(await first.request({
      id: 'set-thinking-current',
      type: 'set_thinking_level',
      level: thinkingLevel,
    }));
    const persistSession = responseData(await first.request({
      id: 'persist-session',
      type: 'bash',
      command: "printf 'PI_APP_RPC_SESSION_PERSISTED\\n'",
    }));
    assert.equal(persistSession.exitCode, 0, 'Direct bash must complete successfully.');
    const directBashMaterializedSession = await pathExists(sessionFile);
    assert.equal(
      directBashMaterializedSession,
      false,
      'A direct RPC bash command must not materialize an otherwise empty session file.',
    );

    const sessionPromptStart = first.recordCount;
    expectSuccess(await first.request({
      id: 'persist-session-prompt',
      type: 'prompt',
      message: 'Reply with exactly PI_APP_RPC_SESSION_PERSISTED. Do not use tools.',
    }));
    await waitForSettled(first, sessionPromptStart, options.timeoutMs);
    await stat(sessionFile);
    await first.close();

    const resumed = await startPi('session-resume', cwd, outputDir, options, [
      '--session',
      sessionFile,
      '--session-dir',
      sessionDir,
      '--no-approve',
      '--no-tools',
      '--no-extensions',
      '--no-skills',
      '--no-prompt-templates',
      '--no-context-files',
    ]);
    try {
      const resumedState = responseData(await resumed.request({
        id: 'state-resumed',
        type: 'get_state',
      }));
      assert.equal(resumedState.sessionId, sessionId, 'Resume must retain the Pi session id.');
      assert.equal(resumedState.sessionFile, sessionFile, 'Resume must retain the session file.');
      return {
        sessionFile: relative(outputDir, sessionFile),
        sessionId,
        model: `${requiredString(model.provider, 'model.provider')}/${requiredString(model.id, 'model.id')}`,
        thinkingLevel,
        availableThinkingLevels,
        availableModelCount: availableModels.length,
        directBashMaterializedSession,
        promptMaterializedSession: true,
        resumedSameSession: true,
      };
    } finally {
      await closeHarness(resumed);
    }
  } finally {
    await closeHarness(first);
  }
}

async function verifyProjectTrust(
  outputDir: string,
  options: VerifyOptions,
): Promise<Record<string, unknown>> {
  const fixtureSource = resolve(process.cwd(), 'fixtures/rpc-untrusted-project');
  await stat(fixtureSource);
  const projectDir = join(outputDir, 'project-trust-fixture');
  await cp(fixtureSource, projectDir, { recursive: true });

  const resourceArgs = [
    '--no-session',
    '--no-context-files',
    '--tools',
    builtinTools.join(','),
  ];
  const untrusted = await startPi('project-untrusted', projectDir, outputDir, options, [
    '--no-approve',
    ...resourceArgs,
  ]);
  try {
    const untrustedCommands = commandNames(
      responseData(await untrusted.request({ id: 'commands-untrusted', type: 'get_commands' })),
    );
    for (const name of projectCommandNames) {
      assert.equal(
        untrustedCommands.includes(name),
        false,
        `--no-approve must not load project resource ${name}.`,
      );
    }
  } finally {
    await closeHarness(untrusted);
  }

  const trusted = await startPi('project-trusted', projectDir, outputDir, options, [
    '--approve',
    ...resourceArgs,
  ]);
  try {
    const trustedCommands = commandNames(
      responseData(await trusted.request({ id: 'commands-trusted', type: 'get_commands' })),
    );
    for (const name of projectCommandNames) {
      assert.equal(
        trustedCommands.includes(name),
        true,
        `--approve must load project resource ${name}.`,
      );
    }

    const startIndex = trusted.recordCount;
    expectSuccess(await trusted.request({
      id: 'project-local-command',
      type: 'prompt',
      message: '/pi-app-rpc-project-probe',
    }));
    const notification = await trusted.waitFor(
      (record) =>
        record.direction === 'stdout' &&
        record.value.type === 'extension_ui_request' &&
        record.value.method === 'notify' &&
        record.value.message === 'pi-app-rpc-project-probe handled',
      'project-local extension notification',
      { fromIndex: startIndex, timeoutMs: options.timeoutMs },
    );
    await wait(250);

    const localRecords = trusted.records.slice(startIndex);
    const localEventTypes = localRecords
      .filter((record) => record.direction === 'stdout')
      .map((record) => String(record.value.type ?? 'unknown'));
    return {
      untrustedProjectResourcesLoaded: false,
      trustedProjectResourcesLoaded: true,
      requestedBuiltinTools: builtinTools,
      trustedCommands: projectCommandNames,
      localCommandNotificationSequence: notification.sequence,
      localCommandEventTypes: [...new Set(localEventTypes)],
      localCommandEmittedAgentStart: localEventTypes.includes('agent_start'),
      localCommandEmittedAgentSettled: localEventTypes.includes('agent_settled'),
    };
  } finally {
    await closeHarness(trusted);
  }
}

async function verifyLiveAgent(
  outputDir: string,
  options: VerifyOptions,
): Promise<Record<string, unknown>> {
  const cwd = join(outputDir, 'live-agent-workspace');
  await mkdir(cwd, { recursive: true });
  const harness = await startPi('live-agent', cwd, outputDir, options, [
    '--no-session',
    '--no-approve',
    '--no-extensions',
    '--no-skills',
    '--no-prompt-templates',
    '--no-context-files',
    '--tools',
    builtinTools.join(','),
  ]);

  try {
    const state = responseData(await harness.request({ id: 'live-state', type: 'get_state' }));
    const model = requiredRecord(state.model, 'live get_state.data.model');
    const provider = requiredString(model.provider, 'live get_state.data.model.provider');
    const modelId = requiredString(model.id, 'live get_state.data.model.id');
    const thinkingLevel = requiredString(state.thinkingLevel, 'live get_state.data.thinkingLevel');

    const availableModels = responseData(await harness.request({
      id: 'live-models',
      type: 'get_available_models',
    }));
    const models = requiredArray(availableModels.models, 'live get_available_models.data.models');
    assert.equal(
      models.some((entry) => isRecord(entry) && entry.provider === provider && entry.id === modelId),
      true,
      'Current model must be selectable through RPC.',
    );
    responseData(await harness.request({
      id: 'live-set-model',
      type: 'set_model',
      provider,
      modelId,
    }));
    expectSuccess(await harness.request({
      id: 'live-set-thinking',
      type: 'set_thinking_level',
      level: thinkingLevel,
    }));

    const textStart = harness.recordCount;
    expectSuccess(await harness.request({
      id: 'live-text-prompt',
      type: 'prompt',
      message: 'Reply with exactly PI_APP_RPC_STREAM_OK. Do not use tools.',
    }));
    await waitForSettled(harness, textStart, options.timeoutMs);
    const textRecords = harness.records.slice(textStart);
    const textDeltaCount = countAssistantDelta(textRecords, 'text_delta');
    const thinkingDeltaCount = countAssistantDelta(textRecords, 'thinking_delta');
    assert.ok(textDeltaCount > 0, 'Expected at least one text_delta from a live prompt.');

    const toolStart = harness.recordCount;
    expectSuccess(await harness.request({
      id: 'live-tool-prompt',
      type: 'prompt',
      message: [
        'Use the bash tool exactly once to run:',
        "printf 'PI_APP_RPC_TOOL_MARKER\\n'",
        'Do not read or edit files. After the tool completes, reply exactly PI_APP_RPC_TOOL_DONE.',
      ].join('\n'),
    }));
    await harness.waitFor(
      (record) => isToolEvent(record, 'tool_execution_start', 'bash'),
      'agent bash tool start',
      { fromIndex: toolStart, timeoutMs: options.timeoutMs },
    );
    await harness.waitFor(
      (record) => isToolEvent(record, 'tool_execution_end', 'bash'),
      'agent bash tool end',
      { fromIndex: toolStart, timeoutMs: options.timeoutMs },
    );
    await waitForSettled(harness, toolStart, options.timeoutMs);
    const toolRecords = harness.records.slice(toolStart);
    const toolThinkingDeltaCount = countAssistantDelta(toolRecords, 'thinking_delta');

    const directBashStart = harness.recordCount;
    const directBash = responseData(await harness.request({
      id: 'live-bash-truncation',
      type: 'bash',
      command: 'yes x | head -c 60000',
    }));
    assert.equal(directBash.truncated, true, 'Direct bash output must report truncation.');
    assert.equal(typeof directBash.fullOutputPath, 'string');
    const bashUpdateCount = harness.records
      .slice(directBashStart)
      .filter(
        (record) => record.direction === 'stdout' && record.value.type === 'bash_execution_update',
      ).length;
    assert.ok(bashUpdateCount > 0, 'Expected streaming bash_execution_update records.');

    const abortStart = harness.recordCount;
    expectSuccess(await harness.request({
      id: 'live-abort-prompt',
      type: 'prompt',
      message: [
        'Use the bash tool exactly once to run sleep 20.',
        'Do not perform any other action before the command starts.',
      ].join(' '),
    }));
    await harness.waitFor(
      (record) => isToolEvent(record, 'tool_execution_start', 'bash'),
      'abort scenario bash tool start',
      { fromIndex: abortStart, timeoutMs: options.timeoutMs },
    );
    expectSuccess(await harness.request({ id: 'live-abort', type: 'abort' }));
    const abortToolEnd = await harness.waitFor(
      (record) => isToolEvent(record, 'tool_execution_end', 'bash'),
      'aborted bash tool end',
      { fromIndex: abortStart, timeoutMs: options.timeoutMs },
    );
    assert.equal(abortToolEnd.value.isError, true, 'Aborted bash tool must finish as an error.');
    assert.match(toolResultText(abortToolEnd), /aborted/i);
    const abortAgentEnd = await harness.waitFor(
      (record) => record.direction === 'stdout' && record.value.type === 'agent_end',
      'aborted agent_end',
      { fromIndex: abortStart, timeoutMs: options.timeoutMs },
    );
    assert.equal(agentEndContainsAbortedStop(abortAgentEnd), true, 'Abort must end with stopReason=aborted.');
    await waitForSettled(harness, abortStart, options.timeoutMs);
    const abortThinkingDeltaCount = countAssistantDelta(
      harness.records.slice(abortStart),
      'thinking_delta',
    );
    const thinkingStreamObserved =
      thinkingDeltaCount + toolThinkingDeltaCount + abortThinkingDeltaCount > 0;

    return {
      model: `${provider}/${modelId}`,
      thinkingLevel,
      textDeltaCount,
      textPromptThinkingDeltaCount: thinkingDeltaCount,
      toolPromptThinkingDeltaCount: toolThinkingDeltaCount,
      abortPromptThinkingDeltaCount: abortThinkingDeltaCount,
      thinkingStreamObserved,
      agentToolLifecycleObserved: true,
      directBashTruncationObserved: true,
      bashExecutionUpdateCount: bashUpdateCount,
      abortSettled: true,
      requestedBuiltinTools: builtinTools,
    };
  } finally {
    await closeHarness(harness);
  }
}

async function verifyQueueControls(
  outputDir: string,
  options: VerifyOptions,
): Promise<Record<string, unknown>> {
  const cwd = join(outputDir, 'queue-controls-workspace');
  await mkdir(cwd, { recursive: true });
  const harness = await startPi('queue-controls', cwd, outputDir, options, [
    '--no-session',
    '--no-approve',
    '--no-extensions',
    '--no-skills',
    '--no-prompt-templates',
    '--no-context-files',
    '--tools',
    builtinTools.join(','),
  ]);

  try {
    const startIndex = harness.recordCount;
    expectSuccess(await harness.request({
      id: 'queue-controls-prompt',
      type: 'prompt',
      message: 'Use the bash tool exactly once to run sleep 2, then reply PI_APP_RPC_QUEUE_ORIGINAL.',
    }));
    await harness.waitFor(
      (record) => isToolEvent(record, 'tool_execution_start', 'bash'),
      'queue controls bash tool start',
      { fromIndex: startIndex, timeoutMs: options.timeoutMs },
    );
    expectSuccess(await harness.request({
      id: 'queue-controls-steer',
      type: 'steer',
      message: 'After the running tool completes, reply PI_APP_RPC_QUEUE_STEER.',
    }));
    expectSuccess(await harness.request({
      id: 'queue-controls-follow-up',
      type: 'follow_up',
      message: 'After the agent settles, reply PI_APP_RPC_QUEUE_FOLLOW_UP.',
    }));
    await waitForSettled(harness, startIndex, options.timeoutMs);

    const records = harness.records.slice(startIndex);
    const queueUpdateCount = records.filter(
      (record) => record.direction === 'stdout' && record.value.type === 'queue_update',
    ).length;
    assert.ok(queueUpdateCount > 0, 'Expected queue_update after steer or follow_up.');
    return {
      steerAccepted: true,
      followUpAccepted: true,
      queueUpdateCount,
      settledAfterQueuedMessages: true,
    };
  } finally {
    await closeHarness(harness);
  }
}

async function verifyProcessExit(
  outputDir: string,
  options: VerifyOptions,
): Promise<Record<string, unknown>> {
  const cwd = join(outputDir, 'process-exit-workspace');
  await mkdir(cwd, { recursive: true });
  const harness = await startPi('process-exit', cwd, outputDir, options, [
    '--no-session',
    '--no-approve',
    '--no-tools',
    '--no-extensions',
    '--no-skills',
    '--no-prompt-templates',
    '--no-context-files',
  ]);

  try {
    const startIndex = harness.recordCount;
    expectSuccess(await harness.request({
      id: 'process-exit-prompt',
      type: 'prompt',
      message: 'Reply with exactly PI_APP_RPC_PROCESS_EXIT_PROBE. Do not use tools.',
    }));
    await harness.waitFor(
      (record) => record.direction === 'stdout' && record.value.type === 'agent_start',
      'agent_start before process termination',
      { fromIndex: startIndex, timeoutMs: options.timeoutMs },
    );
    const exitInfo = await harness.terminate();
    const records = harness.records.slice(startIndex);
    const processExitIndex = records.findIndex(
      (record) => record.direction === 'lifecycle' && record.value.type === 'process_exit',
    );
    assert.ok(processExitIndex >= 0, 'Harness must record Pi process exit.');
    assert.equal(
      records.slice(processExitIndex + 1).length,
      0,
      'No stdout record may be accepted after the process_exit lifecycle record.',
    );

    return {
      exitCode: exitInfo.code,
      exitSignal: exitInfo.signal,
      agentSettledBeforeExit: records.some(
        (record) => record.direction === 'stdout' && record.value.type === 'agent_settled',
      ),
      recordsAfterProcessExit: 0,
    };
  } finally {
    await closeHarness(harness);
  }
}

async function startPi(
  name: string,
  cwd: string,
  outputDir: string,
  options: VerifyOptions,
  args: string[],
): Promise<PiRpcHarness> {
  const harness = await PiRpcHarness.start({
    executable: options.piExecutable,
    args: ['--mode', 'rpc', ...args],
    cwd,
    recordFile: join(outputDir, 'recordings', `${name}.jsonl`),
    timeoutMs: options.timeoutMs,
  });
  activeHarnesses.add(harness);
  return harness;
}

async function closeHarness(harness: PiRpcHarness): Promise<void> {
  activeHarnesses.delete(harness);
  await harness.close();
}

async function waitForSettled(
  harness: PiRpcHarness,
  fromIndex: number,
  timeoutMs: number,
): Promise<void> {
  await harness.waitFor(
    (record) => record.direction === 'stdout' && record.value.type === 'agent_settled',
    'agent_settled',
    { fromIndex, timeoutMs },
  );
}

function isToolEvent(
  record: PiRpcRecordedRecord,
  type: string,
  toolName: string,
): boolean {
  return (
    record.direction === 'stdout' &&
    record.value.type === type &&
    record.value.toolName === toolName
  );
}

function toolResultText(record: PiRpcRecordedRecord): string {
  const result = requiredRecord(record.value.result, 'tool_execution_end.result');
  const content = requiredArray(result.content, 'tool_execution_end.result.content');
  return content
    .filter(isRecord)
    .map((entry) => (typeof entry.text === 'string' ? entry.text : ''))
    .join('\n');
}

function agentEndContainsAbortedStop(record: PiRpcRecordedRecord): boolean {
  const messages = record.value.messages;
  if (!Array.isArray(messages)) {
    return false;
  }
  return messages.some(
    (message) => isRecord(message) && message.role === 'assistant' && message.stopReason === 'aborted',
  );
}

function countAssistantDelta(records: readonly PiRpcRecordedRecord[], type: string): number {
  return records.filter((record) => {
    if (record.direction !== 'stdout' || record.value.type !== 'message_update') {
      return false;
    }
    const event = record.value.assistantMessageEvent;
    return isRecord(event) && event.type === type;
  }).length;
}

function commandNames(data: Record<string, unknown>): string[] {
  const commands = requiredArray(data.commands, 'get_commands.data.commands');
  return commands.map((command) => requiredString(requiredRecord(command, 'command').name, 'command.name'));
}

function responseData(response: Record<string, unknown>): Record<string, unknown> {
  expectSuccess(response);
  return requiredRecord(response.data, 'response.data');
}

function expectSuccess(response: Record<string, unknown>): void {
  assert.equal(response.type, 'response');
  assert.equal(response.success, true, `Pi RPC command failed: ${String(response.error ?? 'unknown')}`);
}

function requiredArray(value: unknown, name: string): unknown[] {
  if (!Array.isArray(value)) {
    throw new PiRpcHarnessError(`${name} must be an array.`);
  }
  return value;
}

function requiredRecord(value: unknown, name: string): Record<string, unknown> {
  if (!isRecord(value)) {
    throw new PiRpcHarnessError(`${name} must be an object.`);
  }
  return value;
}

function requiredString(value: unknown, name: string): string {
  if (typeof value !== 'string' || value.length === 0) {
    throw new PiRpcHarnessError(`${name} must be a non-empty string.`);
  }
  return value;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

async function pathExists(path: string): Promise<boolean> {
  try {
    await stat(path);
    return true;
  } catch (error) {
    if (isRecord(error) && error.code === 'ENOENT') {
      return false;
    }
    throw error;
  }
}

async function readPiVersion(executable: string): Promise<string> {
  const { stdout } = await execFile(executable, ['--version']);
  return stdout.trim();
}

async function writeJson(path: string, value: unknown): Promise<void> {
  await writeFile(path, `${JSON.stringify(value, null, 2)}\n`, 'utf8');
}

function parseOptions(args: string[]): VerifyOptions {
  let outputDir: string | undefined;
  let piExecutable = process.env.PI_APP_PI_EXECUTABLE ?? 'pi';
  let timeoutMs = 45_000;

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (arg === '--output') {
      outputDir = requiredOptionValue(args, ++index, '--output');
      continue;
    }
    if (arg === '--pi') {
      piExecutable = requiredOptionValue(args, ++index, '--pi');
      continue;
    }
    if (arg === '--timeout-ms') {
      timeoutMs = Number(requiredOptionValue(args, ++index, '--timeout-ms'));
      if (!Number.isSafeInteger(timeoutMs) || timeoutMs <= 0) {
        throw new PiRpcHarnessError('--timeout-ms must be a positive integer.');
      }
      continue;
    }
    throw new PiRpcHarnessError(`Unknown option: ${arg}`);
  }

  return { outputDir, piExecutable, timeoutMs };
}

function ensureOutputOutsideRepository(outputDir: string): void {
  const repositoryRoot = resolve(process.cwd(), '..');
  const relativePath = relative(repositoryRoot, outputDir);
  if (
    relativePath.length === 0 ||
    (!relativePath.startsWith('..') && !isAbsolute(relativePath))
  ) {
    throw new PiRpcHarnessError(
      'RPC recordings may contain prompt and event content; --output must be outside the repository.',
    );
  }
}

function requiredOptionValue(args: string[], index: number, option: string): string {
  const value = args[index];
  if (value === undefined || value.startsWith('--')) {
    throw new PiRpcHarnessError(`${option} requires a value.`);
  }
  return value;
}

function wait(milliseconds: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

void main();
