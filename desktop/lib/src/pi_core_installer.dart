import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

class PiCoreInstallerException implements Exception {
  const PiCoreInstallerException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PiCoreInstallerDownloadProgress {
  const PiCoreInstallerDownloadProgress({
    required this.transferredBytes,
    required this.totalBytes,
  });

  final int transferredBytes;
  final int? totalBytes;

  int? get percent {
    final total = totalBytes;
    if (total == null || total <= 0) {
      return null;
    }
    return ((transferredBytes / total) * 100).round().clamp(0, 100).toInt();
  }
}

class PiCoreInstallerBundle {
  const PiCoreInstallerBundle({
    required this.sourceUri,
    required this.rootDirectory,
    required this.scriptFile,
    required this.launcherFile,
    required this.logFile,
  });

  final Uri sourceUri;
  final Directory rootDirectory;
  final File scriptFile;
  final File launcherFile;
  final File logFile;
}

typedef PiCoreInstallerProgressListener =
    void Function(PiCoreInstallerDownloadProgress progress);
typedef PiCoreInstallerWorkingDirectoryProvider = Future<Directory> Function();

abstract interface class PiCoreInstallerClient {
  Future<PiCoreInstallerBundle> prepareInstaller({
    PiCoreInstallerProgressListener? onProgress,
  });

  Future<void> discardInstaller(PiCoreInstallerBundle bundle);
}

class OfficialPiCoreInstallerClient implements PiCoreInstallerClient {
  OfficialPiCoreInstallerClient({
    http.Client? httpClient,
    PiCoreInstallerWorkingDirectoryProvider? workingDirectoryProvider,
  }) : _httpClient = httpClient ?? http.Client(),
       _workingDirectoryProvider =
           workingDirectoryProvider ?? _defaultWorkingDirectory;

  static final Uri sourceUri = Uri.https('pi.dev', '/install.sh');
  static const Duration _downloadTimeout = Duration(seconds: 20);

  final http.Client _httpClient;
  final PiCoreInstallerWorkingDirectoryProvider _workingDirectoryProvider;

  @override
  Future<PiCoreInstallerBundle> prepareInstaller({
    PiCoreInstallerProgressListener? onProgress,
  }) async {
    final rootDirectory = await _workingDirectoryProvider();
    await rootDirectory.create(recursive: true);

    final scriptFile = File(
      '${rootDirectory.path}${Platform.pathSeparator}install.sh',
    );
    final launcherFile = File(
      '${rootDirectory.path}${Platform.pathSeparator}run-pi-core-installer.command',
    );
    final logFile = File(
      '${rootDirectory.path}${Platform.pathSeparator}pi-core-installer.log',
    );

    try {
      final request = http.Request('GET', sourceUri);
      final response = await _httpClient
          .send(request)
          .timeout(_downloadTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw PiCoreInstallerException(
          'Pi installer download returned ${response.statusCode}.',
        );
      }

      final sink = scriptFile.openWrite();
      var transferredBytes = 0;
      final totalBytes = response.contentLength;
      try {
        try {
          await for (final chunk in response.stream) {
            sink.add(chunk);
            transferredBytes += chunk.length;
            onProgress?.call(
              PiCoreInstallerDownloadProgress(
                transferredBytes: transferredBytes,
                totalBytes: totalBytes,
              ),
            );
          }
        } catch (_) {
          throw const PiCoreInstallerException(
            'Could not download the official Pi installer.',
          );
        }
      } finally {
        await sink.close();
      }

      try {
        await _makeExecutable(scriptFile);
        await _writeLogFile(
          logFile,
          scriptFile: scriptFile,
          launcherFile: launcherFile,
        );
        await launcherFile.writeAsString(
          _launcherScript(scriptPath: scriptFile.path, logPath: logFile.path),
          flush: true,
        );
        await _makeExecutable(launcherFile);
      } on PiCoreInstallerException {
        rethrow;
      } catch (_) {
        throw const PiCoreInstallerException(
          'Could not prepare the Pi installer launcher files.',
        );
      }

      return PiCoreInstallerBundle(
        sourceUri: sourceUri,
        rootDirectory: rootDirectory,
        scriptFile: scriptFile,
        launcherFile: launcherFile,
        logFile: logFile,
      );
    } catch (error) {
      await _deleteDirectoryIfExists(rootDirectory);
      if (error is PiCoreInstallerException) {
        rethrow;
      }
      throw const PiCoreInstallerException(
        'Could not prepare the Pi installer.',
      );
    }
  }

  @override
  Future<void> discardInstaller(PiCoreInstallerBundle bundle) async {
    await _deleteDirectoryIfExists(bundle.rootDirectory);
  }

  static Future<Directory> _defaultWorkingDirectory() {
    return Directory.systemTemp.createTemp('pi-app-pi-core-installer-');
  }

  Future<void> _makeExecutable(File file) async {
    if (Platform.isWindows) {
      return;
    }
    final result = await Process.run('chmod', <String>['700', file.path]);
    if (result.exitCode != 0) {
      throw PiCoreInstallerException(
        'Could not prepare the Pi installer launcher script.',
      );
    }
  }

  Future<void> _writeLogFile(
    File logFile, {
    required File scriptFile,
    required File launcherFile,
  }) async {
    await logFile.writeAsString(
      'Pi App prepared the official Pi installer.\n'
      'Source: $sourceUri\n'
      'Script: ${scriptFile.path}\n'
      'Launcher: ${launcherFile.path}\n'
      'Log: ${logFile.path}\n',
      flush: true,
    );
  }

  String _launcherScript({
    required String scriptPath,
    required String logPath,
  }) {
    final sourceValue = _shellQuote(sourceUri.toString());
    final scriptValue = _shellQuote(scriptPath);
    final logValue = _shellQuote(logPath);

    return '''#!/bin/bash
set -u

SOURCE_URL=$sourceValue
SCRIPT_PATH=$scriptValue
LOG_PATH=$logValue

mkdir -p "\$(dirname "\$LOG_PATH")"
touch "\$LOG_PATH"
{
  echo
  echo "Pi App launched the official Pi installer."
  echo "Source: \$SOURCE_URL"
  echo "Script: \$SCRIPT_PATH"
  echo "Log: \$LOG_PATH"
  echo "Started: \$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  echo
} >> "\$LOG_PATH"

clear
cat <<EOF
Pi App launched the official Pi installer.

Source: \$SOURCE_URL
Script: \$SCRIPT_PATH
Log: \$LOG_PATH

Pi App only downloads the official script and opens it in Terminal.
It does not verify the script contents beyond this source URL.
EOF

echo
if command -v script >/dev/null 2>&1; then
  script -aq "\$LOG_PATH" /bin/bash "\$SCRIPT_PATH"
  EXIT_CODE=\$?
else
  /bin/bash "\$SCRIPT_PATH" 2>&1 | tee -a "\$LOG_PATH"
  EXIT_CODE=\${PIPESTATUS[0]}
fi

echo >> "\$LOG_PATH"
echo "Installer exited with code \$EXIT_CODE at \$(date -u '+%Y-%m-%dT%H:%M:%SZ')" >> "\$LOG_PATH"

echo
if [ "\$EXIT_CODE" -eq 0 ]; then
  echo "Installer finished. You can close this Terminal window."
else
  echo "Installer exited with code \$EXIT_CODE. Review the log above or reopen:"
  echo "\$LOG_PATH"
fi

echo
read -r -p "Press Return to close this window..." _
exit "\$EXIT_CODE"
''';
  }

  String _shellQuote(String value) {
    return "'${value.replaceAll("'", "'\"'\"'")}'";
  }

  Future<void> _deleteDirectoryIfExists(Directory directory) async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }
}
