# pi-host

`host/` 是 Pi App 的本地 Node sidecar。Flutter 不直接调用 Pi SDK；它通过 stdin/stdout 的严格 JSONL 协议向 host 创建会话、发送任务、接收流事件并中止运行。

## 运行时边界

- SDK：`@earendil-works/pi-coding-agent@0.82.0`
- Node：`>=22.19.0`
- 配置：复用 `~/.pi/agent`，或 `PI_CODING_AGENT_DIR` 指向的配置根
- session：复用 Pi 标准 JSONL session 存储
- stdout：Pi 的 `output-guard` 会把普通 stdout 重定向到 stderr；只有 raw stdout 可写协议 JSONL
- JSONL：输入、输出单条记录均限制为 1 MiB
- 项目资源：第一轮以未信任状态加载 project-local `.pi` 资源；不会静默执行项目 extension

当前 `session.create` 可接受受限的 `tools` 数组。省略时 host 默认只启用只读工具：`read`、`grep`、`find`、`ls`。Flutter 的“读取工具”对应此集合；用户显式开启“编码工具”后，新 session 才额外启用 `bash`、`edit`、`write`。

这不是文件系统或 shell 沙箱，也没有逐工具确认协议。项目 trust 确认、权限 gate 和 extension UI bridge 属于后续能力；只应在用户信任项目和提示词时打开编码工具。

## 开发

```bash
cd host
npm install
npm run check
npm test
npm run build
```

启动 host 后，可通过标准输入发送一行一个 JSON 对象：

```bash
node dist/src/index.js
```

最小请求序列：

```json
{"id":"health-1","method":"host.health","params":{}}
{"id":"session-1","method":"session.create","params":{"cwd":"/absolute/project/path","tools":["read","grep","find","ls"]}}
{"id":"prompt-1","method":"session.prompt","params":{"sessionId":"<host-session-id>","text":"Review this project."}}
```

第一轮 method：

- `host.health`
- `session.create`
- `session.prompt`
- `session.abort`
- `session.getState`
- `session.listModels`
- `session.setModel`
- `session.setThinkingLevel`

第一轮 event：

- `session.created`、`session.state`
- `run.started`、`run.settled`、`run.aborted`、`run.failed`
- `message.delta`、`thinking.delta`
- `tool.started`、`tool.updated`、`tool.completed`
- `runtime.diagnostic`

`run.settled` 映射 Pi SDK 的 `agent_settled`，表示重试、压缩和队列均已完成；不能把 `agent_end` 当作最终完成事件。若 extension command 或 input handler 在本地处理了 prompt 而未启动 agent，host 也会发出 `run.settled`，并附带 `handledWithoutRun: true`，避免 UI 停在运行中状态。

## Flutter 开发期接线

先构建 host，再从 `desktop/` 启动 Flutter：

```bash
cd host && npm run build
cd ../desktop && flutter run -d macos
```

`LocalPiHostClient` 会从当前开发目录定位 `host/dist/src/index.js`。也可以显式指定：

```bash
PI_HOST_EXECUTABLE=node \
PI_HOST_ENTRYPOINT=/absolute/path/to/host/dist/src/index.js \
flutter run -d macos
```

当前 macOS/Windows/Linux bundle 尚未包含 Node runtime 与 host 依赖，这是打包阶段的待办。独立 bundle 中找不到 sidecar 时，composer 会显示明确的 host 不可用错误。
