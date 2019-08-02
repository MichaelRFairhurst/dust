// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dust/src/vm_result.dart';
import 'package:dust/src/simplify/constraint.dart';

/// Constrains the simplifier to only failed, or only passing, results.
class OutputConstraint implements Constraint {
  final String _output;

  /// Constrain the simplifier to have the provided output.
  OutputConstraint(this._output);

  /// Constrain the simplifier to have the same output as this [VmResult].
  OutputConstraint.sameAs(VmResult result) : _output = result.errorOutput;

  @override
  bool accept(VmResult result) => result.errorOutput == _output;
}
