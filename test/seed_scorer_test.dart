// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:math';

import 'package:fuzz/location.dart';
import 'package:fuzz/location_scorer.dart';
import 'package:fuzz/result.dart';
import 'package:fuzz/seed.dart';
import 'package:fuzz/seed_scorer.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

void main() {
  final location = Location('foo.dart', 0);
  final locationScorer = LocationScorerMock();
  final scorer = SeedScorer(locationScorer);

  test('locations affects score', () {
    Seed seedA = Seed('f', Result(Duration(microseconds: 1), [location]));
    when(locationScorer.scoreAll(seedA.initialResult.locations))
        .thenReturn(1.0);
    expect(scorer.getScore(seedA), 1.0);

    Seed seedB = Seed('f', Result(Duration(microseconds: 1), [location]));
    when(locationScorer.scoreAll(seedB.initialResult.locations))
        .thenReturn(2.0);
    expect(scorer.getScore(seedB), 2.0);
  });

  test('length affects score', () {
    Seed short = Seed('f', Result(Duration(microseconds: 1), [location]));
    when(locationScorer.scoreAll(short.initialResult.locations))
        .thenReturn(1.0);
    expect(scorer.getScore(short), 1.0);

    Seed medium = Seed('this is a longer base input',
        Result(Duration(microseconds: 1), [location]));
    when(locationScorer.scoreAll(medium.initialResult.locations))
        .thenReturn(1.0);
    expect(scorer.getScore(medium), 0.9558112297048122);

    Seed long = Seed('this goes on much longer' + (', and longer' * 20) + '...',
        Result(Duration(microseconds: 1), [location]));
    when(locationScorer.scoreAll(long.initialResult.locations)).thenReturn(1.0);
    expect(scorer.getScore(long), 0.29095709103539774);
  });

  test('time affects score', () {
    Seed fast = Seed('f', Result(Duration(microseconds: 2), [location]));
    when(locationScorer.scoreAll(fast.initialResult.locations)).thenReturn(1.0);
    expect(scorer.getScore(fast), 0.5);

    Seed slow = Seed('f', Result(Duration(microseconds: 4), [location]));
    when(locationScorer.scoreAll(slow.initialResult.locations)).thenReturn(1.0);
    expect(scorer.getScore(slow), 0.25);
  });

  test('failure affects score', () {
    Seed seed =
        Seed('f', Result.failed('...', Duration(microseconds: 1), [location]));
    when(locationScorer.scoreAll(seed.initialResult.locations)).thenReturn(1.0);
  });

  test('all effects', () {
    Seed seed = Seed('this is a longer base input',
        Result.failed('...', Duration(microseconds: 4), [location]));
    when(locationScorer.scoreAll(seed.initialResult.locations)).thenReturn(0.5);

    expect(scorer.getScore(seed), 0.5 * 0.25 * 0.9558112297048122 * 0.05);
  });
}

class LocationScorerMock extends Mock implements LocationScorer {}
