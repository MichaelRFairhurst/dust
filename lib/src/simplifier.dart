// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:dust/src/controller.dart';
import 'package:dust/src/failure.dart';
import 'package:dust/src/failure_library.dart';
import 'package:dust/src/mutators.dart';
import 'package:dust/src/pool.dart';
import 'package:dust/src/result.dart';
import 'package:dust/src/seed.dart';
import 'package:dust/src/seed_library.dart';

/// Simplifies a [Failure] for human troubleshooting.
///
/// Removes characters from a seed and runs it on a [Controller], preserving
/// different characteristics depending on the constraints.
class Simplifier {
  final Failure _targetFailure;
  final Controller _controller;
  final List<SimplifierConstraint> _constraints;

  /// Construct a Driver to run fuzz testing.
  Simplifier(this._targetFailure, this._controller, this._constraints);

  /// Simplify the target [Failure] according to the constraints.
  Future<String> simplify() async {
    var currentState = _targetFailure.input;
    for (var i = currentState.length - 1; i >= 0; --i) {
      final tryState = currentState.replaceRange(i, i + 1, '');
      final result = await _controller.run(tryState);
      if (_constrain(result)) {
        currentState = tryState;
      }
    }
    return currentState;
  }

  bool _constrain(Result result) {
    for (final constraint in _constraints) {
      if (constraint == SimplifierConstraint.failed && result.succeeded) {
        return false;
      }
      if (constraint == SimplifierConstraint.exactPaths) {
        if (Set.from(result.locations)
                .intersection(Set.from(_targetFailure.result.locations))
                .length !=
            result.locations.length) {
          return false;
        }
      }
      if (constraint == SimplifierConstraint.subsetPaths) {
        if (Set.from(result.locations)
            .difference(Set.from(_targetFailure.result.locations))
            .isNotEmpty) {
          return false;
        }
      }
      if (constraint == SimplifierConstraint.fewerPaths) {
        if (result.locations.length < _targetFailure.result.locations.length) {
          return false;
        }
      }
      if (constraint == SimplifierConstraint.sameOutput) {
        if (result.errorOutput != _targetFailure.result.errorOutput) {
          return false;
        }
      }
    }
    return true;
  }
}

/// Constraints for what is deemed a "valid" simplification of a [Failure].
enum SimplifierConstraint {
  /// New paths must be a subset of old paths.
  subsetPaths,

  /// Paths must be fewer than old paths.
  fewerPaths,

  /// Paths must not be changed.
  exactPaths,

  /// Error must not be changed.
  sameOutput,

  /// Any failure
  failed,
}
