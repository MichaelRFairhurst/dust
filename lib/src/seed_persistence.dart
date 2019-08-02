// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dust/src/seed_candidate.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;

/// Means of loading & persisting seeds (both hand-written and generated) from
/// a directory.
class SeedPersistence {
  Directory _corpusDirectory;
  final String _inputDirPath;
  final String _corpusDirPath;

  /// Create a [SeedPersistence] with the [_inputDirPath] directory.
  SeedPersistence(this._corpusDirPath, this._inputDirPath);

  /// Load all seeds recursively within [_inputDirPath], and
  Future<List<SeedCandidate>> load() async {
    _corpusDirectory = Directory(_corpusDirPath);
    if (!(await _corpusDirectory.exists())) {
      await _corpusDirectory.create();
    }

    final results = <SeedCandidate>[];

    await _loadDirectory(_corpusDirectory, results, inCorpus: true);

    if (_inputDirPath != null) {
      final seedDirectory = Directory(_inputDirPath);
      if (!(await seedDirectory.exists())) {
        throw 'No such directory $_inputDirPath';
      }

      await _loadDirectory(seedDirectory, results, inCorpus: false);
    }

    return results;
  }

  /// Save a new generated [seed] to the generated subdirectory.
  Future<void> recordToCorpus(String seed) async {
    final hash = md5.convert(seed.codeUnits).toString();
    final file = File(path.join(_corpusDirectory.path, hash));
    if (!file.existsSync()) {
      await file.writeAsString(seed);
    }
  }

  Future<void> _loadDirectory(Directory directory, List<SeedCandidate> results,
      {@required bool inCorpus}) async {
    await for (final item
        in directory.list(recursive: true, followLinks: true)) {
      if (item is File) {
        try {
          results.add(SeedCandidate.forFile(
              await item.readAsString(), item.path,
              inCorpus: inCorpus));
        } catch (_) {}
      }
    }
  }
}
