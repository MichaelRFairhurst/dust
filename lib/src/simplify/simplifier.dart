// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:dust/src/input_result.dart';
import 'package:dust/src/simplify/constraint.dart';
import 'package:dust/src/vm_controller.dart';

/// Simplifies an [InputResult] for human troubleshooting.
///
/// Removes characters from a seed and runs it on a [VmController], preserving
/// different characteristics depending on the constraints.
class Simplifier {
  static const int _maxChecks = 75;
  final InputResult _originalInputResult;
  final VmController _controller;
  final List<Constraint> _constraints;
  var _checks = 0;
  final _readCoverage;

  /// Construct a Driver to run fuzz testing.
  Simplifier(this._originalInputResult, this._controller, this._constraints)
      : _readCoverage =
            _constraints.any((constraint) => constraint.constrainsCoverage);

  /// Simplify the original [InputResult] according to the constraints.
  Future<String> simplify() => _chunkDown(_originalInputResult.input);

  Future<String> _chunkDown(String original) async {
    var currentState = original;
    var chunkSize = original.length >> 2;
    while (_checks < _maxChecks) {
      if (currentState.isEmpty) {
        return currentState;
      }
      final startingLength = currentState.length;
      final maxChunkSize = currentState.length >> 2;
      if (chunkSize > maxChunkSize) {
        chunkSize = maxChunkSize;
      }
      if (chunkSize < 1) {
        chunkSize = 1;
      }
      final newState = await _removeChunks(currentState, chunkSize);
      if (currentState == newState && chunkSize == 1) {
        break;
      }

      final endingLength = currentState.length;
      final removedLength = startingLength - endingLength;
      final removedChunks = removedLength / chunkSize;
      final removalAttempts = startingLength / chunkSize;
      final optimisticSuccessRate = (removedChunks + 2) / removalAttempts;

      chunkSize = optimisticSuccessRate > 1
          ? chunkSize >> 2
          : (chunkSize * optimisticSuccessRate).floor();
      currentState = newState;
    }

    return currentState;
  }

  Future<String> _removeChunks(String original, int length) async {
    var currentState = original;
    for (var i = currentState.length - 1 - length;
        i + length >= 0 && _checks < _maxChecks;
        i -= length) {
      final tryState = currentState.replaceRange(i < 0 ? 0 : i, i + length, '');
      if (await _try(tryState)) {
        currentState = tryState;
      }
    }
    return currentState;
  }

  Future<bool> _try(String input) async {
    _checks++;
    final result = await _controller.run(input, readCoverage: _readCoverage);
    return _constraints.every((constraint) => constraint.accept(result));
  }
}
