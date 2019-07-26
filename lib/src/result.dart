// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dust/src/location.dart';

/// Details of how the VM executed a run, including potential error output.
class Result {
  /// Potential error output, if the result was a failure.
  final String errorOutput;

  /// The time the VM took during execution.
  final Duration timeElapsed;

  /// The source code locations that the VM executed.
  final List<Location> locations;

  /// Create a [Result] that the VM run succeeded (completed without error).
  Result(this.timeElapsed, this.locations) : errorOutput = null;

  /// Create a [Result] that the VM run failed, and the error output from that.
  Result.failed(this.errorOutput, this.timeElapsed, this.locations);

  /// Whether the VM run succeeded.
  bool get succeeded => errorOutput == null;
}
