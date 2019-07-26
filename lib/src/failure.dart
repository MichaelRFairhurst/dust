// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dust/src/result.dart';

/// Represents a failed VM [Result] and the [input] which triggered it.
class Failure {
  /// The input string that caused the failure.
  final String input;

  /// The VM run result.
  final Result result;

  /// Construct a [Failure] with an [input] string and the VM [Result], which
  /// must be a failed execution run for consistency.
  Failure(this.input, this.result)
      : assert(!result.succeeded,
            'Failure instances should be given Results that failed.');
}
