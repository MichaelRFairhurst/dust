// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:math';

import 'package:dust/src/location.dart';
import 'package:dust/src/location_scorer.dart';
import 'package:dust/src/seed.dart';

/// Determines the value of running a [Seed] based on its original result run
/// and an input [LocationScorer].
///
/// We are trying to estimate the likelihood that mutating a seed will get us
/// new fuzz failures. This is a combination of factors: the uniqueness of its
/// [Location]s, the time it takes to run, and whether it the fuzz case failed.
///
/// We also add in a small human element; we prefer smaller seeds to larger
/// ones, because they are more likely to be failures that catch the essence of
/// a problem. This may do more than just ease debugging the output of the
/// fuzzer, it may also reduce redundant fuzz failure cases (say, the result of
/// removing unnecessary characters from a fuzz case.
///
/// Assuming the uniqueness of the locations have already been scored, it's easy
/// for us to factor in time. Running a seed that takes twice as long but has
/// twice the unique locations is likely to be a wash: S(l) / t.
///
/// Scoring whether a fuzz case failed or not is harder. Heuristically, we can
/// say that a case which failed is much much less likely to fail in a different
/// way on subsequent runs. Currently we penalize it by 95%. This could be
/// changed in the future to account for things like, whether the fuzz failure
/// contains locations not seen in any fuzz successes. Or the tolerance of
/// failure cases could decrease over time as the seed pool increases...or
/// increase over time as the rate of unique failures fall.
///
/// Similarly, scoring shorter seeds is harder. If two seeds are exactly the
/// same, we want the shorter seed to be better. But not infinitely better,
/// because the extra characters may be a transitional path to a new execution.
/// Similarly, scoring two completely different seeds based on length is
/// difficult to quantify. We use an exponential approach so that as seeds get
/// longer they get progressively penalized, and let the smaller seeds rely
/// more on their other metrics. We use 1/(l^1.5 - l^1.4999 + 1)
///
/// Note that the [LocationScorer] will change scores over time, and therefore,
/// this will too.
class SeedScorer {
  final LocationScorer _locationScorer;

  /// Initialize a [SeedScorer] with a custom [LocationScorer].
  SeedScorer(this._locationScorer);

  /// Calculate the score of a [Seed].
  double getScore(Seed seed) =>
      _locationScore(seed) /
      _microseconds(seed) *
      _failurePenalty(seed) *
      _lengthPenalty(seed);

  /// Set the score of a [Seed] to a newly calculated value.
  void score(Seed seed) => seed.score = getScore(seed);

  double _failurePenalty(Seed seed) =>
      seed.initialResult.succeeded ? 1.0 : 0.05;

  double _lengthPenalty(Seed seed) =>
      1 / (pow(seed.input.length, 1.5) - pow(seed.input.length, 1.4999) + 1);

  double _locationScore(Seed seed) =>
      _locationScorer.scoreAll(seed.initialResult.locations);

  int _microseconds(Seed seed) => seed.initialResult.timeElapsed.inMicroseconds;
}
