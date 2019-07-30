// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Stats about the program that do not change over time.
class ProgramStats {
  /// The number of paths to be discovered in coverage
  final int totalPaths;

  /// Initialize program stats.
  ProgramStats(this.totalPaths);
}

/// Stats that change over time.
class ProgressStats {
  /// While [startTime] does not change over time, it is a property of the
  /// progress and not a property of the program itself.
  final DateTime startTime;

  /// The [ProgramStats] to help read these progress stats.
  final ProgramStats programStats;

  /// How many paths have yet been visited by the fuzz cases.
  int visitedPaths = 0;

  /// How many seeds currently exist.
  int numberOfSeeds = 0;

  /// How many unique failures have been reported.
  int numberOfFailures = 0;

  /// How many unique cases have been run.
  int numberOfExecutions = 0;

  /// Begin tracking stats for a program.
  ProgressStats(this.startTime, this.programStats);

  /// What ratio of executions result in a unique failure.
  double get coverageRatio => visitedPaths / programStats.totalPaths;

  /// What ratio of executions result in a unique failure.
  double get failureRate => numberOfFailures / numberOfExecutions;

  /// What ratio of executions result in a seed.
  double get seedRate => numberOfSeeds / numberOfExecutions;
}
