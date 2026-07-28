import 'dart:convert';
import 'dart:io';

import 'package:pi_desktop/pi_core_runtime.dart';

Future<void> main(List<String> arguments) async {
  final executable = _parseExecutable(arguments);
  final detector = PlatformPiCoreRuntimeDetector(
    environment: executable == null
        ? null
        : <String, String>{'PI_CORE_EXECUTABLE': executable},
  );
  final controller = PiCoreRuntimeController(detector: detector);

  try {
    await controller.refresh();
    final snapshot = controller.snapshot;
    if (!snapshot.isReady) {
      throw StateError(
        'Pi core health check failed: ${snapshot.status.name}/${snapshot.diagnosticCode.name}',
      );
    }
    stdout.writeln(
      jsonEncode(<String, dynamic>{
        'ok': true,
        'status': snapshot.status.name,
        'source': snapshot.source?.name,
        'executablePath': snapshot.executablePath,
        'version': snapshot.version,
      }),
    );
  } finally {
    controller.dispose();
  }
}

String? _parseExecutable(List<String> arguments) {
  if (arguments.isEmpty) {
    return null;
  }
  if (arguments.length == 2 && arguments.first == '--pi') {
    return arguments.last;
  }
  throw ArgumentError(
    'Usage: dart run tool/verify_pi_core_runtime.dart [--pi PATH]',
  );
}
