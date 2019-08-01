// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';

import 'package:dust/src/failure.dart';
import 'package:dust/src/location.dart';

/// A way to collect and dedupe failures
class FailureLibrary {
  /// Previous failures indexed by their truncated error output.
  final _previousFailuresByOutput = <String, Failure>{};

  /// Report a [Failure], and returns its original if it exists.
  Failure report(Failure failure) {
    var error = failure.result.errorOutput;
    if (error.startsWith('timed out')) {
      // TODO: use LSH to do near-duplicate detection by coverage.
      return null;
    }

    error = error.substring(0, error.length > 500 ? 500 : error.length);
    if (_previousFailuresByOutput.keys.contains(error)) {
      return _previousFailuresByOutput[error];
    }

    // TODO: fall back to LSH to do near-duplicate detection by coverage.
    _previousFailuresByOutput[error] = failure;
    return null;
  }
}
