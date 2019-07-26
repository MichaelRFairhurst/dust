// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dust/src/failure.dart';

/// A way to collect and dedupe failures
class FailureLibrary {
  /// Previous failures indexed by their truncated error output.
  final _previousFailures = <String, Failure>{};

  /// Report a [Failure], and returns its original if it exists.
  Failure report(Failure failure) {
    var error = failure.result.errorOutput;
    error = error.substring(0, error.length > 500 ? 500 : error.length);
    if (_previousFailures.keys.contains(error)) {
      return _previousFailures[error];
    }

    _previousFailures[error] = failure;
    return null;
  }
}
