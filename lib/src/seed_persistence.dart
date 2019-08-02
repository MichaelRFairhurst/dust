// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:crypto/crypto.dart';

/// Means of loading & persisting seeds (both hand-written and generated) from
/// a directory.
class SeedPersistence {
  Directory _generatedSeedsFolder;
  final String _path;

  /// Create a [SeedPersistence] with the [_path] directory.
  SeedPersistence(this._path);

  /// Load all seeds recursively within [_path], and
  Future<List<String>> load() async {
    final directory = Directory(_path);
    if (!(await directory.exists())) {
      throw "No surch directory $_path";
    }

    final results = <String>[];
    await for (final item
        in directory.list(recursive: true, followLinks: true)) {
      if (item is File) {
        results.add(await item.readAsString());
      }
    }

    _generatedSeedsFolder = Directory('$_path/_generated');
    if (!(await _generatedSeedsFolder.exists())) {
      await _generatedSeedsFolder.create();
    }

    return results;
  }

  /// Save a new generated [seed] to the generated subdirectory.
  Future<void> recordGeneratedSeed(String seed) async {
    final hash = md5.convert(seed.codeUnits).toString();
    final file = File('${_generatedSeedsFolder.path}/$hash');
    if (!file.existsSync()) {
      await file.writeAsString(seed);
    }
  }
}
