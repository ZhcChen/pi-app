import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

enum AppUpdateAvailability { notSupported, upToDate, available, unavailable }

class AppUpdateException implements Exception {
  const AppUpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AppUpdateRuntime {
  const AppUpdateRuntime({
    required this.currentVersion,
    required this.isSupported,
  });

  final String currentVersion;
  final bool isSupported;
}

abstract interface class AppUpdateRuntimeProvider {
  Future<AppUpdateRuntime> loadRuntime();
}

typedef PackageInfoLoader = Future<PackageInfo> Function();

class PackageInfoAppUpdateRuntimeProvider implements AppUpdateRuntimeProvider {
  PackageInfoAppUpdateRuntimeProvider({
    PackageInfoLoader? packageInfoLoader,
    bool Function()? isMacOS,
    bool? isReleaseBuild,
  }) : _packageInfoLoader = packageInfoLoader ?? PackageInfo.fromPlatform,
       _isMacOS = isMacOS ?? (() => Platform.isMacOS),
       _isReleaseBuild = isReleaseBuild ?? kReleaseMode;

  final PackageInfoLoader _packageInfoLoader;
  final bool Function() _isMacOS;
  final bool _isReleaseBuild;

  @override
  Future<AppUpdateRuntime> loadRuntime() async {
    final packageInfo = await _packageInfoLoader();
    return AppUpdateRuntime(
      currentVersion: packageInfo.version,
      isSupported: _isReleaseBuild && _isMacOS(),
    );
  }
}

class AppUpdateRelease {
  const AppUpdateRelease({
    required this.tag,
    required this.version,
    required this.releaseUri,
    required this.downloadUri,
    required this.assetName,
    required this.releaseNotes,
    this.publishedAt,
  });

  final String tag;
  final String version;
  final Uri releaseUri;
  final Uri downloadUri;
  final String assetName;
  final String releaseNotes;
  final DateTime? publishedAt;
}

class AppUpdateCheck {
  const AppUpdateCheck({
    required this.availability,
    required this.currentVersion,
    this.release,
    this.message,
  });

  const AppUpdateCheck.notSupported({required String currentVersion})
    : this(
        availability: AppUpdateAvailability.notSupported,
        currentVersion: currentVersion,
      );

  const AppUpdateCheck.upToDate({required String currentVersion})
    : this(
        availability: AppUpdateAvailability.upToDate,
        currentVersion: currentVersion,
      );

  const AppUpdateCheck.unavailable({
    required String currentVersion,
    required String message,
  }) : this(
         availability: AppUpdateAvailability.unavailable,
         currentVersion: currentVersion,
         message: message,
       );

  final AppUpdateAvailability availability;
  final String currentVersion;
  final AppUpdateRelease? release;
  final String? message;

  bool get hasUpdate => availability == AppUpdateAvailability.available;
}

class AppUpdateDownloadProgress {
  const AppUpdateDownloadProgress({
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

typedef AppUpdateProgressListener =
    void Function(AppUpdateDownloadProgress progress);
typedef AppUpdateDownloadsDirectoryProvider = Future<Directory> Function();

abstract interface class AppUpdateClient {
  Future<AppUpdateCheck> checkForUpdate();

  Future<File> downloadUpdate({
    required AppUpdateRelease release,
    AppUpdateProgressListener? onProgress,
  });
}

class GitHubAppUpdateClient implements AppUpdateClient {
  GitHubAppUpdateClient({
    http.Client? httpClient,
    AppUpdateRuntimeProvider? runtimeProvider,
    AppUpdateDownloadsDirectoryProvider? downloadsDirectoryProvider,
  }) : _httpClient = httpClient ?? http.Client(),
       _runtimeProvider =
           runtimeProvider ?? PackageInfoAppUpdateRuntimeProvider(),
       _downloadsDirectoryProvider =
           downloadsDirectoryProvider ?? _defaultDownloadsDirectory;

  static const String _owner = 'ZhcChen';
  static const String _repository = 'pi-app';
  static final Uri _latestReleaseUri = Uri.https(
    'api.github.com',
    '/repos/$_owner/$_repository/releases/latest',
  );

  final http.Client _httpClient;
  final AppUpdateRuntimeProvider _runtimeProvider;
  final AppUpdateDownloadsDirectoryProvider _downloadsDirectoryProvider;

  @override
  Future<AppUpdateCheck> checkForUpdate() async {
    final runtime = await _runtimeProvider.loadRuntime();
    final currentVersion = runtime.currentVersion;

    if (!runtime.isSupported) {
      return AppUpdateCheck.notSupported(currentVersion: currentVersion);
    }

    final response = await _httpClient
        .get(
          _latestReleaseUri,
          headers: const <String, String>{
            'accept': 'application/vnd.github+json',
            'user-agent': 'Pi-App',
          },
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 404) {
      return AppUpdateCheck.unavailable(
        currentVersion: currentVersion,
        message: 'No published Pi App release is available yet.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AppUpdateException(
        'GitHub release check returned ${response.statusCode}.',
      );
    }

    final payload = _asMap(
      jsonDecode(response.body),
      'GitHub release response',
    );
    if (payload['draft'] == true || payload['prerelease'] == true) {
      return AppUpdateCheck.upToDate(currentVersion: currentVersion);
    }

    final tag = _requiredString(payload['tag_name'], 'tag_name');
    final version = _normalizeVersion(tag);
    final releaseUri = _releaseUriFor(payload['html_url'], tag);
    final comparison = compareAppVersions(version, currentVersion);

    if (comparison <= 0) {
      return AppUpdateCheck.upToDate(currentVersion: currentVersion);
    }

    final assetName = 'Pi-App-$version-macos-universal.dmg';
    final asset = _matchingAsset(payload['assets'], assetName, tag);
    if (asset == null) {
      return AppUpdateCheck.unavailable(
        currentVersion: currentVersion,
        message: 'The latest release does not contain the universal macOS DMG.',
      );
    }

    final publishedAt = _parseOptionalDate(payload['published_at']);
    final notes = payload['body'] is String ? payload['body'] as String : '';
    return AppUpdateCheck(
      availability: AppUpdateAvailability.available,
      currentVersion: currentVersion,
      release: AppUpdateRelease(
        tag: tag,
        version: version,
        releaseUri: releaseUri,
        downloadUri: asset.downloadUri,
        assetName: assetName,
        releaseNotes: notes,
        publishedAt: publishedAt,
      ),
    );
  }

  @override
  Future<File> downloadUpdate({
    required AppUpdateRelease release,
    AppUpdateProgressListener? onProgress,
  }) async {
    final expectedVersion = _normalizeVersion(release.tag);
    final expectedAssetName = 'Pi-App-$expectedVersion-macos-universal.dmg';
    if (release.version != expectedVersion ||
        release.assetName != expectedAssetName) {
      throw const AppUpdateException('The update release metadata is invalid.');
    }
    _releaseUriFor(release.releaseUri.toString(), release.tag);
    if (!isAllowedReleaseDownloadUri(
      release.downloadUri,
      tag: release.tag,
      assetName: release.assetName,
    )) {
      throw const AppUpdateException('The update download URL is not allowed.');
    }

    final directory = await _downloadsDirectoryProvider();
    await directory.create(recursive: true);

    final target = File(
      '${directory.path}${Platform.pathSeparator}${release.assetName}',
    );
    final partial = File('${target.path}.part');
    await _deleteIfExists(partial);

    IOSink? sink;
    try {
      final request = http.Request('GET', release.downloadUri);
      request.headers['user-agent'] = 'Pi-App';
      final response = await _httpClient
          .send(request)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AppUpdateException(
          'Update download returned ${response.statusCode}.',
        );
      }

      sink = partial.openWrite();
      var transferredBytes = 0;
      onProgress?.call(
        AppUpdateDownloadProgress(
          transferredBytes: transferredBytes,
          totalBytes: response.contentLength,
        ),
      );

      await for (final chunk in response.stream) {
        sink.add(chunk);
        transferredBytes += chunk.length;
        onProgress?.call(
          AppUpdateDownloadProgress(
            transferredBytes: transferredBytes,
            totalBytes: response.contentLength,
          ),
        );
      }

      await sink.flush();
      await sink.close();
      sink = null;
      await _deleteIfExists(target);
      return partial.rename(target.path);
    } catch (_) {
      final activeSink = sink;
      if (activeSink != null) {
        try {
          await activeSink.close();
        } catch (_) {}
      }
      try {
        await _deleteIfExists(partial);
      } catch (_) {}
      rethrow;
    }
  }

  static int compareAppVersions(String left, String right) {
    final leftParts = _AppVersion.parse(left);
    final rightParts = _AppVersion.parse(right);

    for (final pair in <(int, int)>[
      (leftParts.major, rightParts.major),
      (leftParts.minor, rightParts.minor),
      (leftParts.patch, rightParts.patch),
    ]) {
      final comparison = pair.$1.compareTo(pair.$2);
      if (comparison != 0) {
        return comparison;
      }
    }

    if (leftParts.prerelease.isEmpty && rightParts.prerelease.isNotEmpty) {
      return 1;
    }
    if (leftParts.prerelease.isNotEmpty && rightParts.prerelease.isEmpty) {
      return -1;
    }

    final length = leftParts.prerelease.length > rightParts.prerelease.length
        ? leftParts.prerelease.length
        : rightParts.prerelease.length;
    for (var index = 0; index < length; index += 1) {
      final leftIdentifier = index < leftParts.prerelease.length
          ? leftParts.prerelease[index]
          : null;
      final rightIdentifier = index < rightParts.prerelease.length
          ? rightParts.prerelease[index]
          : null;
      if (leftIdentifier == null) {
        return -1;
      }
      if (rightIdentifier == null) {
        return 1;
      }

      final comparison = _comparePrereleaseIdentifier(
        leftIdentifier,
        rightIdentifier,
      );
      if (comparison != 0) {
        return comparison;
      }
    }

    return 0;
  }

  static bool isAllowedReleaseDownloadUri(
    Uri uri, {
    required String tag,
    required String assetName,
  }) {
    final expected = Uri.https(
      'github.com',
      '/$_owner/$_repository/releases/download/$tag/$assetName',
    );
    return uri.scheme == expected.scheme &&
        uri.host == expected.host &&
        uri.port == expected.port &&
        uri.path == expected.path &&
        uri.query.isEmpty &&
        uri.fragment.isEmpty;
  }

  static Future<Directory> _defaultDownloadsDirectory() async {
    final home = Platform.environment['HOME'];
    if (home != null && home.isNotEmpty) {
      return Directory(
        '$home${Platform.pathSeparator}Downloads${Platform.pathSeparator}Pi App Updates',
      );
    }
    return Directory(
      '${Directory.systemTemp.path}${Platform.pathSeparator}Pi App Updates',
    );
  }

  static Future<void> _deleteIfExists(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }

  static _ReleaseAsset? _matchingAsset(
    Object? rawAssets,
    String assetName,
    String tag,
  ) {
    if (rawAssets is! List) {
      throw const AppUpdateException('GitHub release assets are missing.');
    }

    for (final rawAsset in rawAssets) {
      if (rawAsset is! Map) {
        continue;
      }
      final asset = Map<String, dynamic>.from(rawAsset);
      if (asset['name'] != assetName) {
        continue;
      }
      final rawUri = asset['browser_download_url'];
      if (rawUri is! String || rawUri.trim().isEmpty) {
        continue;
      }
      final uri = Uri.tryParse(rawUri.trim());
      if (uri == null ||
          !isAllowedReleaseDownloadUri(uri, tag: tag, assetName: assetName)) {
        continue;
      }
      return _ReleaseAsset(downloadUri: uri);
    }

    return null;
  }

  static Uri _releaseUriFor(Object? rawUri, String tag) {
    final uri = Uri.tryParse(_requiredString(rawUri, 'html_url'));
    final expected = Uri.https(
      'github.com',
      '/$_owner/$_repository/releases/tag/$tag',
    );
    if (uri == null ||
        uri.scheme != expected.scheme ||
        uri.host != expected.host ||
        uri.port != expected.port ||
        uri.path != expected.path ||
        uri.query.isNotEmpty ||
        uri.fragment.isNotEmpty) {
      throw const AppUpdateException('GitHub release page URL is not allowed.');
    }
    return uri;
  }

  static Map<String, dynamic> _asMap(Object? value, String label) {
    if (value is! Map) {
      throw AppUpdateException('$label must be an object.');
    }
    return Map<String, dynamic>.from(value);
  }

  static String _requiredString(Object? value, String label) {
    if (value is! String || value.trim().isEmpty) {
      throw AppUpdateException('$label must be a non-empty string.');
    }
    return value.trim();
  }

  static String _normalizeVersion(String version) {
    final normalized = version.trim().replaceFirst(
      RegExp(r'^v', caseSensitive: false),
      '',
    );
    _AppVersion.parse(normalized);
    return normalized;
  }

  static DateTime? _parseOptionalDate(Object? value) {
    if (value is! String || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value)?.toUtc();
  }

  static int _comparePrereleaseIdentifier(String left, String right) {
    final leftNumeric = int.tryParse(left);
    final rightNumeric = int.tryParse(right);
    if (leftNumeric != null && rightNumeric != null) {
      return leftNumeric.compareTo(rightNumeric);
    }
    if (leftNumeric != null) {
      return -1;
    }
    if (rightNumeric != null) {
      return 1;
    }
    return left.compareTo(right);
  }
}

class _ReleaseAsset {
  const _ReleaseAsset({required this.downloadUri});

  final Uri downloadUri;
}

class _AppVersion {
  const _AppVersion({
    required this.major,
    required this.minor,
    required this.patch,
    required this.prerelease,
  });

  final int major;
  final int minor;
  final int patch;
  final List<String> prerelease;

  factory _AppVersion.parse(String source) {
    final normalized = source.trim().replaceFirst(
      RegExp(r'^v', caseSensitive: false),
      '',
    );
    final match = RegExp(
      r'^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?(?:\+[0-9A-Za-z.-]+)?$',
    ).firstMatch(normalized);
    if (match == null) {
      throw AppUpdateException('Invalid semantic version: $source.');
    }
    final prerelease = match.group(4)?.split('.') ?? const <String>[];
    if (prerelease.any(
      (identifier) =>
          RegExp(r'^\d+$').hasMatch(identifier) &&
          identifier.length > 1 &&
          identifier.startsWith('0'),
    )) {
      throw AppUpdateException('Invalid semantic version: $source.');
    }
    return _AppVersion(
      major: int.parse(match.group(1)!),
      minor: int.parse(match.group(2)!),
      patch: int.parse(match.group(3)!),
      prerelease: prerelease,
    );
  }
}
