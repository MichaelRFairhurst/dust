// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dust/src/path.dart';

/// Details of how the VM executed a run, including potential error output.
class VmResult {
  /// Potential error output, if the result was a failure.
  final String errorOutput;

  /// The time the VM took during execution.
  final Duration timeElapsed;

  /// The source code paths that the VM executed.
  final List<Path> paths;

  /// Create a [VmResult] that the VM run succeeded (completed without error).
  VmResult(this.timeElapsed, this.paths) : errorOutput = null;

  /// Create a [VmResult] that the run failed, and the error output from that.
  VmResult.failed(this.errorOutput, this.timeElapsed, this.paths);

  /// Whether the VM run succeeded.
  bool get succeeded => errorOutput == null;

  @override
  String toString() => '${succeeded ? 'succeeded' : 'failed: $errorOutput'}'
      '\nin ${timeElapsed.inMilliseconds}ms';
}
