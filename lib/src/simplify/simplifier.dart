// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:dust/src/input_result.dart';
import 'package:dust/src/simplify/constraint.dart';
import 'package:dust/src/vm_controller.dart';
import 'package:dust/src/vm_result.dart';

/// Simplifies an [InputResult] for human troubleshooting.
///
/// Removes characters from a seed and runs it on a [VmController], preserving
/// different characteristics depending on the constraints.
class Simplifier {
  static const int _maxChecksSingle = 75;
  static const int _maxChecksFixedPoint = _maxChecksSingle * 5;
  final InputResult _originalInputResult;
  final VmController _controller;
  final List<Constraint> _constraints;
  int _allowedChecks;
  final bool _readCoverage;

  /// Construct a Driver to run fuzz testing.
  Simplifier(this._originalInputResult, this._controller, this._constraints)
      : _readCoverage =
            _constraints.any((constraint) => constraint.constrainsCoverage);

  /// Simplify the original [InputResult] according to the constraints.
  Future<InputResult> simplify() {
    _allowedChecks = _maxChecksSingle;
    return _chunkDown(_originalInputResult);
  }

  /// Run the simplifier repeatedly until it reaches a fixed point.
  ///
  /// Note, it may still not reach a fixed point because it has an upper limit
  /// of maximum allowed checks. It also may return different results than
  /// re-running
  Future<InputResult> simplifyToFixedPoint() async {
    _allowedChecks = _maxChecksFixedPoint;
    var oldResult = _originalInputResult;
    var newResult = await _chunkDown(oldResult);
    while (oldResult != newResult) {
      oldResult = newResult;
      newResult = await _chunkDown(oldResult, isRerun: true);
    }

    return newResult;
  }

  Future<InputResult> _chunkDown(InputResult originalResult,
      {bool isRerun = false}) async {
    //_allowedChecks = 0;
    var currentResult = originalResult;
    var currentString = originalResult.input;
    var chunkSize = currentString.length; // will get cut down by half
    while (_allowedChecks > 0) {
      if (currentString.isEmpty) {
        return currentResult;
      }
      final startingLength = currentString.length;
      final maxChunkSize = currentString.length >> 2;
      if (chunkSize > maxChunkSize) {
        chunkSize = maxChunkSize;
      }
      if (chunkSize < 1) {
        chunkSize = 1;
      }
      if (currentResult == originalResult && isRerun && chunkSize == 1) {
        // single char removal was already run to a fixed point, and we have not
        // broken out of the fixed point through chunk removal.
        break;
      }
      currentResult = await _removeChunks(currentResult, chunkSize);
      currentString = currentResult.input;
      if (chunkSize == 1) {
        break;
      }

      final endingLength = currentString.length;
      final removedLength = startingLength - endingLength;
      final removedChunks = removedLength / chunkSize;
      final removalAttempts = startingLength / chunkSize;
      final optimisticSuccessRate = (removedChunks + 2) / removalAttempts;

      chunkSize = optimisticSuccessRate > 1
          ? chunkSize >> 2
          : (chunkSize * optimisticSuccessRate).floor();
    }

    return currentResult;
  }

  Future<InputResult> _removeChunks(InputResult original, int length) async {
    if (length == 1) {
      return _sweepChars(original);
    }

    var currentResult = original;
    var currentString = original.input;
    for (var i = currentString.length - length;
        i + length > 0 && _allowedChecks > 0;
        i -= length) {
      final tryString =
          currentString.replaceRange(i < 0 ? 0 : i, i + length, '');
      final newResult = await _try(tryString);
      if (newResult != null) {
        currentString = tryString;
        currentResult = InputResult(currentString, newResult);
      }
    }
    return currentResult;
  }

  Future<InputResult> _sweepChars(InputResult original) async {
    var currentResult = original;
    var currentString = original.input;
    var reversing = false;
    int restartIndex;

    bool needsReverse(int i) => i < 0 || i == currentString.length;
    bool done(int i) => needsReverse(i) && restartIndex == null;
    int next(int i) {
      final inc = reversing ? i - 1 : i + 1;
      if (needsReverse(inc) && restartIndex != null) {
        reversing = !reversing;
        final result = restartIndex;
        restartIndex = null;
        return result;
      }

      return inc;
    }

    int previous(i) => reversing ? i : i - 1;

    for (var i = 0; _allowedChecks > 0 && !done(i); i = next(i)) {
      final tryString = currentString.replaceRange(i, i + 1, '');
      final newResult = await _try(tryString);
      if (newResult != null) {
        restartIndex = previous(i);
        currentString = tryString;
        currentResult = InputResult(currentString, newResult);
        if (!reversing) {
          i--; // account for removed char.
        }
      }
    }

    return currentResult;
  }

  Future<VmResult> _try(String input) async {
    try {
      _allowedChecks--;
      final result = await _controller.run(input, readCoverage: _readCoverage);
      if (_constraints.every((constraint) => constraint.accept(result))) {
        return result;
      }
    } catch (e, st) {
      // TODO: accept an error handler
      print('error during simplification\n$e\n$st\n$input');
      if (_allowedChecks > 0) {
        await _controller.dispose();
        await _controller.prestart();
        return _try(input);
      }
    }
    return null;
  }
}
