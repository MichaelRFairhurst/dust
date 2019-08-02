// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dust/src/path.dart';
import 'package:dust/src/simplify/constraint.dart';
import 'package:dust/src/vm_result.dart';

/// Constraint that the coverage must be the exact same coverage.
class ExactPathsConstraint implements Constraint {
  final Set<Path> _expectedCoverage;

  /// Constraint that the coverage must be a subset of the provided coverage.
  ExactPathsConstraint(this._expectedCoverage);

  /// Constraint that the coverage must be a subset of the provided result's
  /// coverage.
  ExactPathsConstraint.sameAs(VmResult result)
      : _expectedCoverage = Set.from(result.paths);

  @override
  bool accept(VmResult result) =>
      Set.from(result.paths).intersection(_expectedCoverage).length ==
      result.paths.length;
}
