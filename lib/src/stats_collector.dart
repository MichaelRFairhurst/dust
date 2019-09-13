// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'package:dust/src/driver.dart';
import 'package:dust/src/path_scorer.dart';
import 'package:dust/src/stats.dart';

/// Service to automatically collect stats from events in the system.
class StatsCollector {
  /// Stats about the program progress.
  final Stats stats;

  /// Create a collector to gather information in additon to the [programStats].
  StatsCollector(this.stats);

  /// Listen to a [Driver] and [PathScorer] for events that fill out the
  /// [programStats].
  void collectFrom(Driver driver) {
    driver.onSuccess.listen((_) => stats.numberOfExecutions++);
    driver.onDuplicateFail.listen((_) => stats.numberOfExecutions++);
    driver.onUniqueFail.listen((_) {
      stats.numberOfExecutions++;
      stats.numberOfFailures++;
    });
    driver.onNewSeed.listen((_) => stats.numberOfSeeds++);
    driver.onSeedCandidateProcessed.listen((candidate) {
      stats.numberOfExecutions++;
      if (candidate.accepted) {
        stats.numberOfSeeds++;
      }
    });
  }
}
