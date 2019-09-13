// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dust/src/coverage_tracker.dart';

/// Stats about current progress in fuzzing.
class Stats {
  /// The [startTime] does not change over time, it is a property of the
  /// progress and not a property of the program itself.
  final DateTime startTime;

  final CoverageTracker _coverageTracker;

  /// How many seeds currently exist.
  int numberOfSeeds = 0;

  /// How many unique failures have been reported.
  int numberOfFailures = 0;

  /// How many unique cases have been run.
  int numberOfExecutions = 0;

  /// Begin tracking stats for a program.
  Stats(this.startTime, this._coverageTracker);

  /// What ratio of known paths have been visited.
  double get coverageRatio => visitedPaths / totalPaths;

  /// What ratio of executions result in a unique failure.
  double get failureRate => numberOfFailures / numberOfExecutions;

  /// What ratio of known files have been visited.
  double get fileCoverageRatio => visitedFiles / totalFiles;

  /// What ratio of known files have been visited.
  double get fileRatio => visitedFiles / totalFiles;

  /// What ratio of executions result in a seed.
  double get seedRate => numberOfSeeds / numberOfExecutions;

  /// How many files have not been compiled by the fuzz cases.
  int get totalFiles => _coverageTracker.totalFiles;

  /// How many paths have been compiled by the fuzz cases.
  int get totalPaths => _coverageTracker.totalPaths;

  /// How many files have been at least partially compiled by the fuzz cases.
  int get visitedFiles => _coverageTracker.visitedFiles;

  /// How many paths have yet been visited by the fuzz cases.
  int get visitedPaths => _coverageTracker.visitedPaths;
}
