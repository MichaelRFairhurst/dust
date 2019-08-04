// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dust/src/simplify/constraint.dart';
import 'package:dust/src/vm_result.dart';

/// Constrains the simplifier to only failed, or only passing, results.
class SucceededConstraint implements Constraint {
  final bool _expectation;

  /// Constrain the simplifier to only failed results.
  SucceededConstraint.failed() : _expectation = false;

  /// Constrain the simplifier to have the same success as the provided result.
  SucceededConstraint.sameAs(VmResult result) : _expectation = result.succeeded;

  /// Constrain the simplifier to only successful results.
  SucceededConstraint.succeeded() : _expectation = true;

  @override
  bool get constrainsCoverage => false;

  @override
  bool accept(VmResult result) => result.succeeded == _expectation;
}
