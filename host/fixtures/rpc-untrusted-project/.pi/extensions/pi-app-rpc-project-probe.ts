import type { ExtensionAPI } from '@earendil-works/pi-coding-agent';

export default function registerPiAppRpcProjectProbe(pi: ExtensionAPI): void {
  pi.registerCommand('pi-app-rpc-project-probe', {
    description: 'Pi App R1 project-local RPC probe',
    handler: async (_args, ctx) => {
      ctx.ui.notify('pi-app-rpc-project-probe handled', 'info');
    },
  });
}
