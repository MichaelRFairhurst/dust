// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dust/src/location.dart';
import 'package:dust/src/location_scorer.dart';
import 'package:test/test.dart';

void main() {
  final locationA = Location('foo.dart', 0);
  final locationB = Location('foo.dart', 1);

  group('a scorer with sensitivity of 1', () {
    final scorer = LocationScorer(1);

    test('a unique location gets a score of 1', () {
      scorer.report(locationA);
      expect(scorer.score(locationA), 1.0);
    });

    test('unreported locations fall back to a score of 1', () {
      expect(scorer.score(locationB), 1.0);
    });

    test("other locations don't affect the score", () {
      scorer..report(locationB)..report(locationB);
      expect(scorer.score(locationA), 1.0);
    });

    test('second occurrence gets a score of 0.5', () {
      scorer.report(locationA);
      expect(scorer.score(locationA), 0.5);
    });

    test('tenth occurrence gets a score of 0.1', () {
      for (var i = 2; i < 10; ++i) {
        scorer.report(locationA);
      }
      expect(scorer.score(locationA), 0.1);
    });
  });

  group('scorers with different sensitivities', () {
    test('a unique location always gets a score of 1', () {
      for (var i = 1.0; i < 500; i *= 2) {
        final scorer = LocationScorer(i)..report(locationA);
        expect(scorer.score(locationA), 1.0);
      }
    });

    test('a scorer with sensitivity of 2 goes from 1 to 0.25', () {
      final scorer = LocationScorer(2)..report(locationA)..report(locationA);
      expect(scorer.score(locationA), 0.25);
    });
  });

  test('score all', () {
    final scorer = LocationScorer(1)
      ..report(locationA)
      ..report(locationA)
      ..report(locationB)
      ..report(locationB)
      ..report(locationB);

    expect(scorer.scoreAll([locationA]), 0.5);
    expect(scorer.scoreAll([locationB]), 1 / 3);
    expect(scorer.scoreAll([locationA, locationB]), 0.5 + 1 / 3);
  });
}
