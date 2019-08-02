// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dust/src/vm_result.dart';
import 'package:dust/src/simplify/constraint.dart';

/// Constraint that the coverage must be fewer in count than prior coverage.
class FewerPathsConstraint implements Constraint {
  final int _maxPaths;

  /// Constraint that the coverage must cover less than this number.
  FewerPathsConstraint(this._maxPaths);

  /// Constraint that the coverage must cover fewer paths than the given result.
  FewerPathsConstraint.thanResult(VmResult result)
      : _maxPaths = result.paths.length;

  @override
  bool accept(VmResult result) => result.paths.length <= _maxPaths;
}
