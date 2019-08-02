// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:math';

import 'package:dust/src/path.dart';
import 'package:dust/src/path_scorer.dart';
import 'package:dust/src/seed.dart';
import 'package:dust/src/seed_scorer.dart';
import 'package:dust/src/vm_result.dart';
import 'package:dust/src/weighted_random_choice.dart';

/// Manage [Seed]s, from choosing them randomly to rescoring them to adding new
/// ones to the pool.
class SeedLibrary {
  final List<Seed> _seeds;
  final WeightedOptions<Seed> _weightedSeeds;

  int _needsRescore = 0;
  int _rescoreInterval = 3;
  final SeedScorer _scorer;
  final PathScorer _pathScorer;

  /// Create a [SeedLibrary] with a custom [PathScorer].
  factory SeedLibrary(PathScorer pathScorer) {
    final seeds = <Seed>[];
    final weightedSeeds = WeightedOptions<Seed>(seeds, (seed) => seed.score);

    return SeedLibrary._(
        SeedScorer(pathScorer), pathScorer, seeds, weightedSeeds);
  }

  SeedLibrary._(
      this._scorer, this._pathScorer, this._seeds, this._weightedSeeds);

  /// Get the next batch of [n] [Seed]s, randomly chosen by their scores.
  List<Seed> getBatch(int n, Random random) {
    _potentiallyRescore();

    final seeds = _weightedSeeds.chooseMany(n, random);
    return seeds;
  }

  /// Report a [VmResult] and potentially add it as a new [Seed].
  ///
  /// If the [VmResult] is added as a new [Seed], that new [Seed] is returned.
  Seed report(String input, VmResult result) {
    final keepVmResult = result.paths.any(_pathScorer.isNew);
    result.paths.forEach(_pathScorer.report);

    if (keepVmResult) {
      final seed = Seed(input, result);
      _addSeed(seed);
      return seed;
    }

    return null;
  }

  /// Get the unique paths for this result (making it worthy of being a new
  /// seed).
  List<Path> uniquePaths(VmResult result) =>
      result.paths.where(_pathScorer.isNew).toList();

  void _addSeed(Seed seed) {
    _potentiallyRescore();
    _scorer.score(seed);
    _seeds.add(seed);
  }

  void _potentiallyRescore() {
    if (_needsRescore++ > _rescoreInterval) {
      _seeds.forEach(_scorer.score);
      _needsRescore = 0;
      _rescoreInterval++;
    }
  }
}
