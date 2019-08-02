// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';

import 'package:dust/src/input_result.dart';

/// A way to collect and dedupe failures
class FailureLibrary {
  /// Previous failures indexed by their truncated error output.
  final _previousInputResultsByOutput = <String, InputResult>{};

  /// Report a [InputResult], and returns its original if it exists.
  InputResult report(InputResult failure) {
    assert(!failure.result.succeeded);
    var error = failure.result.errorOutput;
    if (error.startsWith('timed out')) {
      // TODO: use LSH to do near-duplicate detection by coverage.
      return null;
    }

    error = error.substring(0, error.length > 500 ? 500 : error.length);
    if (_previousInputResultsByOutput.keys.contains(error)) {
      return _previousInputResultsByOutput[error];
    }

    // TODO: fall back to LSH to do near-duplicate detection by coverage.
    _previousInputResultsByOutput[error] = failure;
    return null;
  }
}
