// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dust/src/path.dart';
import 'package:dust/src/simplify/constraint.dart';
import 'package:dust/src/vm_result.dart';

/// Constraint that the coverage must be a superset of prior coverage.
class SupersetPathsConstraint implements Constraint {
  final Set<Path> _subset;

  /// Constraint that the coverage must be a superset of the provided coverage.
  SupersetPathsConstraint(this._subset);

  /// Constraint that the coverage must be a superset of the provided VmResult's
  /// coverage.
  SupersetPathsConstraint.ofResult(VmResult result)
      : _subset = Set.from(result.paths);

  @override
  bool get constrainsCoverage => true;

  @override
  bool accept(VmResult result) =>
      Set.from(result.paths).intersection(_subset).length == _subset.length;
}
