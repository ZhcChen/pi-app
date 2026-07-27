import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pi_desktop/src/app_update_service.dart';

class _StaticRuntimeProvider implements AppUpdateRuntimeProvider {
  const _StaticRuntimeProvider(this.runtime);

  final AppUpdateRuntime runtime;

  @override
  Future<AppUpdateRuntime> loadRuntime() async => runtime;
}

class _StreamingClient extends http.BaseClient {
  _StreamingClient(this._handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest request)
  _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _handler(request);
  }
}

String _releasePayload({
  String tag = 'v1.0.1',
  String? releaseUrl,
  List<Map<String, String>>? assets,
}) {
  final version = tag.replaceFirst(RegExp(r'^v'), '');
  return jsonEncode(<String, Object?>{
    'tag_name': tag,
    'html_url':
        releaseUrl ?? 'https://github.com/ZhcChen/pi-app/releases/tag/$tag',
    'draft': false,
    'prerelease': false,
    'published_at': '2026-07-27T00:00:00Z',
    'body': 'Release notes',
    'assets':
        assets ??
        <Map<String, String>>[
          <String, String>{
            'name': 'Pi-App-$version-macos-universal.dmg',
            'browser_download_url':
                'https://github.com/ZhcChen/pi-app/releases/download/$tag/Pi-App-$version-macos-universal.dmg',
          },
        ],
  });
}

void main() {
  AppUpdateRuntime supportedRuntime([String version = '1.0.0']) {
    return AppUpdateRuntime(currentVersion: version, isSupported: true);
  }

  test('compares stable and prerelease semantic versions', () {
    expect(GitHubAppUpdateClient.compareAppVersions('1.0.1', '1.0.0'), 1);
    expect(GitHubAppUpdateClient.compareAppVersions('1.0.0', '1.0.0'), 0);
    expect(GitHubAppUpdateClient.compareAppVersions('1.0.0', '1.0.0-rc.1'), 1);
    expect(
      GitHubAppUpdateClient.compareAppVersions('1.0.0-rc.2', '1.0.0-rc.1'),
      1,
    );
    expect(
      () => GitHubAppUpdateClient.compareAppVersions('1.0.0-01', '1.0.0'),
      throwsA(isA<AppUpdateException>()),
    );
  });

  test('skips GitHub checks outside a supported release runtime', () async {
    var requested = false;
    final client = GitHubAppUpdateClient(
      runtimeProvider: const _StaticRuntimeProvider(
        AppUpdateRuntime(currentVersion: '1.0.0', isSupported: false),
      ),
      httpClient: MockClient((_) async {
        requested = true;
        return http.Response('unexpected', 500);
      }),
    );

    final result = await client.checkForUpdate();

    expect(result.availability, AppUpdateAvailability.notSupported);
    expect(requested, isFalse);
  });

  test('reads the installed version without checking GitHub', () async {
    var requested = false;
    final client = GitHubAppUpdateClient(
      runtimeProvider: const _StaticRuntimeProvider(
        AppUpdateRuntime(currentVersion: '1.2.3', isSupported: true),
      ),
      httpClient: MockClient((_) async {
        requested = true;
        return http.Response('unexpected', 500);
      }),
    );

    expect(await client.getCurrentVersion(), '1.2.3');
    expect(requested, isFalse);
  });

  test('returns a newer universal macOS release from GitHub', () async {
    final client = GitHubAppUpdateClient(
      runtimeProvider: _StaticRuntimeProvider(supportedRuntime()),
      httpClient: MockClient(
        (_) async => http.Response(_releasePayload(), 200),
      ),
    );

    final result = await client.checkForUpdate();

    expect(result.availability, AppUpdateAvailability.available);
    expect(result.currentVersion, '1.0.0');
    expect(result.release?.version, '1.0.1');
    expect(result.release?.assetName, 'Pi-App-1.0.1-macos-universal.dmg');
  });

  test(
    'does not offer an update when the installed version is newer',
    () async {
      final client = GitHubAppUpdateClient(
        runtimeProvider: _StaticRuntimeProvider(supportedRuntime('1.1.0')),
        httpClient: MockClient(
          (_) async => http.Response(_releasePayload(), 200),
        ),
      );

      final result = await client.checkForUpdate();

      expect(result.availability, AppUpdateAvailability.upToDate);
    },
  );

  test(
    'rejects release assets outside the expected GitHub download path',
    () async {
      final client = GitHubAppUpdateClient(
        runtimeProvider: _StaticRuntimeProvider(supportedRuntime()),
        httpClient: MockClient(
          (_) async => http.Response(
            _releasePayload(
              assets: <Map<String, String>>[
                <String, String>{
                  'name': 'Pi-App-1.0.1-macos-universal.dmg',
                  'browser_download_url':
                      'https://example.test/Pi-App-1.0.1-macos-universal.dmg',
                },
              ],
            ),
            200,
          ),
        ),
      );

      final result = await client.checkForUpdate();

      expect(result.availability, AppUpdateAvailability.unavailable);
    },
  );

  test('rejects an unexpected GitHub release page URL', () async {
    final client = GitHubAppUpdateClient(
      runtimeProvider: _StaticRuntimeProvider(supportedRuntime()),
      httpClient: MockClient(
        (_) async => http.Response(
          _releasePayload(
            releaseUrl: 'https://github.com.evil/releases/tag/v1.0.1',
          ),
          200,
        ),
      ),
    );

    await expectLater(
      client.checkForUpdate(),
      throwsA(isA<AppUpdateException>()),
    );
  });

  test('rejects a GitHub release page with an unexpected port', () async {
    final client = GitHubAppUpdateClient(
      runtimeProvider: _StaticRuntimeProvider(supportedRuntime()),
      httpClient: MockClient(
        (_) async => http.Response(
          _releasePayload(
            releaseUrl: 'https://github.com:444/releases/tag/v1.0.1',
          ),
          200,
        ),
      ),
    );

    await expectLater(
      client.checkForUpdate(),
      throwsA(isA<AppUpdateException>()),
    );
  });

  test('does not accept caller-provided update filenames', () async {
    final downloadsDirectory = await Directory.systemTemp.createTemp(
      'pi-app-update-invalid-name-',
    );
    addTearDown(() async {
      if (await downloadsDirectory.exists()) {
        await downloadsDirectory.delete(recursive: true);
      }
    });
    final client = GitHubAppUpdateClient(
      runtimeProvider: _StaticRuntimeProvider(supportedRuntime()),
      downloadsDirectoryProvider: () async => downloadsDirectory,
    );
    final release = AppUpdateRelease(
      tag: 'v1.0.1',
      version: '1.0.1',
      releaseUri: Uri.parse(
        'https://github.com/ZhcChen/pi-app/releases/tag/v1.0.1',
      ),
      downloadUri: Uri.parse(
        'https://github.com/ZhcChen/pi-app/releases/download/v1.0.1/Pi-App-1.0.1-macos-universal.dmg',
      ),
      assetName: '../../outside.dmg',
      releaseNotes: '',
    );

    await expectLater(
      client.downloadUpdate(release: release),
      throwsA(isA<AppUpdateException>()),
    );
    expect(await downloadsDirectory.list().isEmpty, isTrue);
  });

  test('only discards installers in the managed downloads directory', () async {
    final downloadsDirectory = await Directory.systemTemp.createTemp(
      'pi-app-update-discard-',
    );
    final externalDirectory = await Directory.systemTemp.createTemp(
      'pi-app-update-external-',
    );
    addTearDown(() async {
      for (final directory in <Directory>[
        downloadsDirectory,
        externalDirectory,
      ]) {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      }
    });
    final client = GitHubAppUpdateClient(
      runtimeProvider: _StaticRuntimeProvider(supportedRuntime()),
      downloadsDirectoryProvider: () async => downloadsDirectory,
    );
    final managedInstaller = File(
      '${downloadsDirectory.path}${Platform.pathSeparator}Pi-App-1.0.1-macos-universal.dmg',
    );
    final externalInstaller = File(
      '${externalDirectory.path}${Platform.pathSeparator}external.dmg',
    );
    await managedInstaller.writeAsString('managed');
    await externalInstaller.writeAsString('external');

    await client.discardUpdate(managedInstaller);
    await expectLater(
      client.discardUpdate(externalInstaller),
      throwsA(isA<AppUpdateException>()),
    );

    expect(await managedInstaller.exists(), isFalse);
    expect(await externalInstaller.exists(), isTrue);
  });

  test('removes partial downloads when the stream fails', () async {
    final downloadsDirectory = await Directory.systemTemp.createTemp(
      'pi-app-update-stream-failure-',
    );
    addTearDown(() async {
      if (await downloadsDirectory.exists()) {
        await downloadsDirectory.delete(recursive: true);
      }
    });
    final client = GitHubAppUpdateClient(
      runtimeProvider: _StaticRuntimeProvider(supportedRuntime()),
      downloadsDirectoryProvider: () async => downloadsDirectory,
      httpClient: _StreamingClient((request) async {
        if (request.url.path.endsWith('/releases/latest')) {
          final bytes = utf8.encode(_releasePayload());
          return http.StreamedResponse(
            Stream<List<int>>.value(bytes),
            200,
            contentLength: bytes.length,
          );
        }
        final controller = StreamController<List<int>>();
        scheduleMicrotask(() {
          controller
            ..add(<int>[1, 2])
            ..addError(StateError('connection lost'))
            ..close();
        });
        return http.StreamedResponse(controller.stream, 200, contentLength: 4);
      }),
    );

    final check = await client.checkForUpdate();
    await expectLater(
      client.downloadUpdate(release: check.release!),
      throwsA(isA<StateError>()),
    );
    expect(await downloadsDirectory.list().isEmpty, isTrue);
  });

  test(
    'downloads a verified release asset and reports byte progress',
    () async {
      final downloadsDirectory = await Directory.systemTemp.createTemp(
        'pi-app-update-download-',
      );
      addTearDown(() async {
        if (await downloadsDirectory.exists()) {
          await downloadsDirectory.delete(recursive: true);
        }
      });

      final client = GitHubAppUpdateClient(
        runtimeProvider: _StaticRuntimeProvider(supportedRuntime()),
        downloadsDirectoryProvider: () async => downloadsDirectory,
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/releases/latest')) {
            return http.Response(_releasePayload(), 200);
          }
          if (request.url.path.endsWith('.dmg')) {
            return http.Response.bytes(
              <int>[1, 2, 3, 4],
              200,
              headers: const <String, String>{'content-length': '4'},
            );
          }
          return http.Response('not found', 404);
        }),
      );

      final check = await client.checkForUpdate();
      final updates = <AppUpdateDownloadProgress>[];
      final file = await client.downloadUpdate(
        release: check.release!,
        onProgress: updates.add,
      );

      expect(await file.readAsBytes(), <int>[1, 2, 3, 4]);
      expect(updates.last.transferredBytes, 4);
      expect(updates.last.totalBytes, 4);
      expect(updates.last.percent, 100);
    },
  );
}
