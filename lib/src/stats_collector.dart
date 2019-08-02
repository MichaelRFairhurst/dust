// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'package:dust/src/driver.dart';
import 'package:dust/src/location_scorer.dart';
import 'package:dust/src/stats.dart';

/// Service to automatically collect stats from events in the system.
class StatsCollector {
  /// Stats about the program that do not change.
  final ProgramStats programStats;

  /// Stats about the program progress.
  final ProgressStats progressStats;

  /// Create a collector to gather information in additon to the [programStats].
  StatsCollector(this.programStats)
      : progressStats = ProgressStats(DateTime.now(), programStats);

  /// Listen to a [Driver] and [LocationScorer] for events that fill out the
  /// [programStats].
  void collectFrom(Driver driver, LocationScorer locationScorer) {
    driver.onSuccess.listen((_) => progressStats.numberOfExecutions++);
    driver.onDuplicateFail.listen((_) => progressStats.numberOfExecutions++);
    driver.onUniqueFail.listen((_) {
      progressStats.numberOfExecutions++;
      progressStats.numberOfFailures++;
    });
    driver.onNewSeed.listen((_) => progressStats.numberOfSeeds++);
    driver.onSeedCandidateProcessed.listen((candidate) {
      progressStats.numberOfExecutions++;
      if (candidate.accepted) {
        progressStats.numberOfSeeds++;
      }
    });
    locationScorer.onNewLocation.listen((_) => progressStats.visitedPaths++);
  }
}
