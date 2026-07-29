import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pi_desktop/src/pi_core_installer.dart';

class _StreamingClient extends http.BaseClient {
  _StreamingClient(this._handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest request)
  _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _handler(request);
  }
}

void main() {
  test(
    'downloads the official Pi installer and creates launcher files',
    () async {
      final workingDirectory = await Directory.systemTemp.createTemp(
        'pi-core-installer-download-',
      );
      addTearDown(() async {
        if (await workingDirectory.exists()) {
          await workingDirectory.delete(recursive: true);
        }
      });

      final client = OfficialPiCoreInstallerClient(
        workingDirectoryProvider: () async => workingDirectory,
        httpClient: _StreamingClient((request) async {
          expect(request.url, OfficialPiCoreInstallerClient.sourceUri);
          return http.StreamedResponse(
            Stream<List<int>>.fromIterable(const <List<int>>[
              <int>[1, 2],
              <int>[3, 4],
            ]),
            200,
            contentLength: 4,
          );
        }),
      );

      final progressUpdates = <PiCoreInstallerDownloadProgress>[];
      final bundle = await client.prepareInstaller(
        onProgress: progressUpdates.add,
      );

      expect(bundle.sourceUri, OfficialPiCoreInstallerClient.sourceUri);
      expect(await bundle.scriptFile.readAsBytes(), <int>[1, 2, 3, 4]);
      expect(await bundle.launcherFile.exists(), isTrue);
      expect(await bundle.logFile.exists(), isTrue);
      expect(progressUpdates.last.transferredBytes, 4);
      expect(progressUpdates.last.totalBytes, 4);
      expect(progressUpdates.last.percent, 100);

      final launcher = await bundle.launcherFile.readAsString();
      final log = await bundle.logFile.readAsString();
      expect(launcher, contains('Pi App launched the official Pi installer.'));
      expect(
        launcher,
        contains(OfficialPiCoreInstallerClient.sourceUri.toString()),
      );
      expect(log, contains(OfficialPiCoreInstallerClient.sourceUri.toString()));
      expect(log, contains(bundle.scriptFile.path));
      expect(log, contains(bundle.launcherFile.path));
    },
  );

  test(
    'cleans up partial installer files when the download stream fails',
    () async {
      Directory? workingDirectory;
      final client = OfficialPiCoreInstallerClient(
        workingDirectoryProvider: () async {
          workingDirectory = await Directory.systemTemp.createTemp(
            'pi-core-installer-failure-',
          );
          return workingDirectory!;
        },
        httpClient: _StreamingClient((request) async {
          expect(request.url, OfficialPiCoreInstallerClient.sourceUri);
          final controller = StreamController<List<int>>();
          scheduleMicrotask(() {
            controller
              ..add(<int>[1, 2])
              ..addError(StateError('connection lost'))
              ..close();
          });
          return http.StreamedResponse(
            controller.stream,
            200,
            contentLength: 4,
          );
        }),
      );

      await expectLater(
        client.prepareInstaller(),
        throwsA(isA<PiCoreInstallerException>()),
      );
      expect(workingDirectory, isNotNull);
      expect(await workingDirectory!.exists(), isFalse);
    },
  );

  test('discardInstaller removes the prepared installer directory', () async {
    final workingDirectory = await Directory.systemTemp.createTemp(
      'pi-core-installer-discard-',
    );
    final client = OfficialPiCoreInstallerClient(
      workingDirectoryProvider: () async => workingDirectory,
      httpClient: _StreamingClient((request) async {
        expect(request.url, OfficialPiCoreInstallerClient.sourceUri);
        return http.StreamedResponse(
          Stream<List<int>>.value(const <int>[1, 2, 3, 4]),
          200,
          contentLength: 4,
        );
      }),
    );

    final bundle = await client.prepareInstaller();
    expect(await workingDirectory.exists(), isTrue);

    await client.discardInstaller(bundle);

    expect(await workingDirectory.exists(), isFalse);
  });
}
