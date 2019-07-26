// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dust/src/location.dart';
import 'package:dust/src/location_scorer.dart';
import 'package:dust/src/result.dart';
import 'package:dust/src/seed.dart';
import 'package:dust/src/seed_scorer.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

void main() {
  final location = Location('foo.dart', 0);
  final locationScorer = LocationScorerMock();
  final scorer = SeedScorer(locationScorer);

  test('locations affects score', () {
    final seedA = Seed('f', Result(Duration(microseconds: 1), [location]));
    when(locationScorer.scoreAll(seedA.initialResult.locations)).thenReturn(1);
    expect(scorer.getScore(seedA), 1);

    final seedB = Seed('f', Result(Duration(microseconds: 1), [location]));
    when(locationScorer.scoreAll(seedB.initialResult.locations)).thenReturn(2);
    expect(scorer.getScore(seedB), 2);
  });

  test('length affects score', () {
    final short = Seed('f', Result(Duration(microseconds: 1), [location]));
    when(locationScorer.scoreAll(short.initialResult.locations)).thenReturn(1);
    expect(scorer.getScore(short), 1);

    final medium = Seed('this is a longer base input',
        Result(Duration(microseconds: 1), [location]));
    when(locationScorer.scoreAll(medium.initialResult.locations)).thenReturn(1);
    expect(scorer.getScore(medium), 0.9558112297048122);

    final long = Seed('this goes on much longer${', and longer' * 20}...',
        Result(Duration(microseconds: 1), [location]));
    when(locationScorer.scoreAll(long.initialResult.locations)).thenReturn(1);
    expect(scorer.getScore(long), 0.29095709103539774);
  });

  test('time affects score', () {
    final fast = Seed('f', Result(Duration(microseconds: 2), [location]));
    when(locationScorer.scoreAll(fast.initialResult.locations)).thenReturn(1);
    expect(scorer.getScore(fast), 0.5);

    final slow = Seed('f', Result(Duration(microseconds: 4), [location]));
    when(locationScorer.scoreAll(slow.initialResult.locations)).thenReturn(1);
    expect(scorer.getScore(slow), 0.25);
  });

  test('failure affects score', () {
    final seed =
        Seed('f', Result.failed('...', Duration(microseconds: 1), [location]));
    when(locationScorer.scoreAll(seed.initialResult.locations)).thenReturn(1);
  });

  test('all effects', () {
    final seed = Seed('this is a longer base input',
        Result.failed('...', Duration(microseconds: 4), [location]));
    when(locationScorer.scoreAll(seed.initialResult.locations)).thenReturn(0.5);

    expect(scorer.getScore(seed), 0.5 * 0.25 * 0.9558112297048122 * 0.05);
  });
}

class LocationScorerMock extends Mock implements LocationScorer {}
