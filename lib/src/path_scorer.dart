// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:math';

import 'package:dust/src/coverage_tracker.dart';
import 'package:dust/src/path.dart';

/// Determines the uniqueness of a [Path] against all previously seen
/// [Path]s and a configurable "sensitivity."
///
/// When a [Path] is seen it must be reported via [report]. Note, this is
/// NOT an idempotent operation. Take care each [Path] is reported exactly
/// once.
///
/// The score of a [Path] is 1/n^s where n is the number of fuzz cases that
/// have executed that path, and s is the sensitivity.
///
/// A higher sensitivity will value a few rare [Path]s over a large number
/// of common [Path]s. There is a balance to be struck here. A good default
/// value to experiment from is 2.
///
/// Also note that the score of a [Path] will change over time. In the case
/// of a fuzz tester, a new path may be interesting at first, but become less
/// interesting as it fuzzes based on that seed, and the new interesting paths
/// get repetivitely explored.
///
/// TODO: score unique files as well as unique paths?
class PathScorer {
  final CoverageTracker _coverageTracker;

  final double _sensitivity;

  /// Create a new [PathScorer] with the given sensitivity and [PathTracker].
  PathScorer(this._coverageTracker, this._sensitivity);

  /// Check if a [Path] has been seen previously by this scorer.
  bool isNew(Path path) => !_coverageTracker.hasOccurred(path);

  /// Report a [Path] for scoring later.
  void report(Path path) => _coverageTracker.reportPathOccurred(path);

  /// Score a [Path] (higher is more unique).
  double score(Path path) =>
      pow(1.0 / (_coverageTracker.occurrenceCount(path)), _sensitivity);

  /// Score a set of [Path]s (higher is more unique).
  double scoreAll(List<Path> paths) => paths.map(score).reduce((a, b) => a + b);
}
