import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pi_desktop/main.dart';

void main() {
  test('file session reference store persists known sessions', () async {
    final root = await Directory.systemTemp.createTemp('pi-session-store-');
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    final store = FilePiSessionReferenceStore(rootDirectory: root);
    const snapshot = PiSessionReferenceSnapshot(
      references: <PiSessionReference>[
        PiSessionReference(
          projectId: 'project-a',
          projectPath: '/workspace/project-a',
          sessionFile: '/workspace/project-a/.pi/session-a.jsonl',
          sessionName: '分析项目A',
          lastKnownSessionId: 'pi-session-a',
          lastOpenedAt: '2026-07-30T12:00:00.000Z',
        ),
      ],
    );

    await store.saveSnapshot(snapshot);
    final reloaded = await store.loadSnapshot();
    final savedFile = store.resolveIndexFile();

    expect(await savedFile.exists(), true);
    expect(reloaded.references, hasLength(1));
    expect(reloaded.references.single.projectId, 'project-a');
    expect(reloaded.references.single.sessionName, '分析项目A');
    expect(
      reloaded.references.single.sessionFile,
      '/workspace/project-a/.pi/session-a.jsonl',
    );
  });

  test('session reference snapshot upserts and filters by project', () {
    const original = PiSessionReferenceSnapshot(
      references: <PiSessionReference>[
        PiSessionReference(
          projectId: 'project-a',
          projectPath: '/workspace/project-a',
          sessionFile: '/workspace/project-a/.pi/session-a.jsonl',
          sessionName: '旧会话',
          lastKnownSessionId: 'pi-session-a',
          lastOpenedAt: '2026-07-30T11:00:00.000Z',
        ),
        PiSessionReference(
          projectId: 'project-b',
          projectPath: '/workspace/project-b',
          sessionFile: '/workspace/project-b/.pi/session-b.jsonl',
          sessionName: '项目B',
          lastKnownSessionId: 'pi-session-b',
          lastOpenedAt: '2026-07-30T10:00:00.000Z',
        ),
      ],
    );

    final updated = original.upsertReference(
      const PiSessionReference(
        projectId: 'project-a',
        projectPath: '/workspace/project-a',
        sessionFile: '/workspace/project-a/.pi/session-a.jsonl',
        sessionName: '新会话',
        lastKnownSessionId: 'pi-session-a-2',
        lastOpenedAt: '2026-07-30T12:30:00.000Z',
      ),
    );

    final projectAReferences = updated.referencesForProject(
      projectId: 'project-a',
      projectPath: '/workspace/project-a',
    );

    expect(updated.references, hasLength(2));
    expect(projectAReferences, hasLength(1));
    expect(projectAReferences.single.sessionName, '新会话');
    expect(projectAReferences.single.lastKnownSessionId, 'pi-session-a-2');
  });
}
