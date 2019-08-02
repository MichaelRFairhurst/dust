// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dust/src/vm_result.dart';

/// Represents a [VmResult] and the [input] which triggered it.
class InputResult {
  /// The input string that caused the failure.
  final String input;

  /// The VM run result.
  final VmResult result;

  /// Construct an [InputResult] with an [input] string and the [VmResult].
  InputResult(this.input, this.result);
}
