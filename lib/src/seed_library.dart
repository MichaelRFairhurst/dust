// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:math';

import 'package:dust/src/location_scorer.dart';
import 'package:dust/src/result.dart';
import 'package:dust/src/seed.dart';
import 'package:dust/src/seed_scorer.dart';
import 'package:dust/src/weighted_random_choice.dart';

/// Manage [Seed]s, from choosing them randomly to rescoring them to adding new
/// ones to the pool.
class SeedLibrary {
  final List<Seed> _seeds;
  final WeightedOptions<Seed> _weightedSeeds;

  int _needsRescore = 0;
  int _rescoreInterval = 3;
  final SeedScorer _scorer;
  final LocationScorer _locationScorer;

  /// Create a [SeedLibrary] with a custom [LocationScorer].
  factory SeedLibrary(LocationScorer locationScorer) {
    final seeds = <Seed>[];
    final weightedSeeds = WeightedOptions<Seed>(seeds, (seed) => seed.score);

    return SeedLibrary._(
        SeedScorer(locationScorer), locationScorer, seeds, weightedSeeds);
  }

  SeedLibrary._(
      this._scorer, this._locationScorer, this._seeds, this._weightedSeeds);

  /// Get the next batch of [n] [Seed]s, randomly chosen by their scores.
  List<Seed> getBatch(int n, Random random) {
    _potentiallyRescore();

    final seeds = _weightedSeeds.chooseMany(n, random);
    return seeds;
  }

  /// Report a [Result] and potentially add it as a new [Seed].
  ///
  /// If the [Result] is added as a new [Seed], that new [Seed] is returned.
  Seed report(String input, Result result) {
    final keepResult = result.locations.any(_locationScorer.isNew);
    result.locations.forEach(_locationScorer.report);

    if (keepResult) {
      final seed = Seed(input, result);
      _addSeed(seed);
      return seed;
    }

    return null;
  }

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
