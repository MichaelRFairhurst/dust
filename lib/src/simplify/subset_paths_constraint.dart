// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dust/src/path.dart';
import 'package:dust/src/simplify/constraint.dart';
import 'package:dust/src/vm_result.dart';

/// Constraint that the coverage must be a subset of prior coverage.
class SubsetPathsConstraint implements Constraint {
  final Set<Path> _superset;

  /// Constraint that the coverage must be a subset of the provided coverage.
  SubsetPathsConstraint(this._superset);

  /// Constraint that the coverage must be a subset of the provided Result's
  /// coverage.
  SubsetPathsConstraint.ofResult(VmResult result)
      : _superset = Set.from(result.paths);

  @override
  bool get constrainsCoverage => true;

  @override
  bool accept(VmResult result) =>
      Set.from(result.paths).difference(_superset).isNotEmpty;
}
