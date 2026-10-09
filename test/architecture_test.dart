import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Enforces the dependency rule: inner layers never import outer ones.
void main() {
  final importPattern = RegExp(
    r'''^import\s+['"]([^'"]+)['"]''',
    multiLine: true,
  );
  final features = Directory(
    'lib/features',
  ).listSync().whereType<Directory>().map((d) => d.path).toList();

  Iterable<(String, String)> importsUnder(String dir) sync* {
    if (!Directory(dir).existsSync()) return;
    for (final entity in Directory(dir).listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      for (final match in importPattern.allMatches(source)) {
        yield (entity.path, match.group(1)!);
      }
    }
  }

  test('features exist', () => expect(features, isNotEmpty));

  for (final feature in features) {
    test('$feature/domain is pure Dart', () {
      final violations = [
        for (final (file, uri) in importsUnder('$feature/domain'))
          if (uri.startsWith('package:') ||
              uri.contains('/data/') ||
              uri.contains('/presentation/'))
            '$file -> $uri',
      ];
      expect(violations, isEmpty);
    });

    test('$feature/presentation never imports a data layer', () {
      final violations = [
        for (final (file, uri) in importsUnder('$feature/presentation'))
          if (uri.contains('/data/') ||
              const [
                'package:sqflite',
                'package:geolocator',
                'package:image_picker',
                'package:gal',
                'package:share_plus',
              ].any(uri.startsWith))
            '$file -> $uri',
      ];
      expect(violations, isEmpty);
    });
  }
}
