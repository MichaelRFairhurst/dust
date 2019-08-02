// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dust/src/input_result.dart';
import 'package:path/path.dart' as path;

/// Records failures to a directory by hash with error output.
class FailurePersistence {
  final String _path;
  Directory _directory;

  /// Create a [FailurePersistence] with the [_path] directory.
  FailurePersistence(this._path);

  /// Load all seeds recursively within [_path], and
  Future<void> load() async {
    _directory = Directory(_path);
    if (!(await _directory.exists())) {
      throw 'No surch directory $_path';
    }
  }

  /// Save a new failure to the generated subdirectory.
  Future<void> recordFailure(InputResult failure) async {
    assert(!failure.result.succeeded);
    final hash = md5.convert(failure.input.codeUnits).toString();
    final file = File(path.join(_directory.path, hash));
    if (!file.existsSync()) {
      await file
          .writeAsString('${failure.input}\n${failure.result.errorOutput}');
    }
  }
}
