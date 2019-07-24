// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:math';

import 'package:fuzz/weighted_random_choice.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

void main() {
  test('empty options throw an exception', () {
    final options = WeightedOptions<int>([], (i) => i.toDouble());
    try {
      options.choose(Random());
    } catch (e) {
      return;
    }
    fail('expected an exception');
  });

  test('a single option is always chosen', () {
    final options = WeightedOptions<int>([1], (i) => i.toDouble());
    final random = Random();
    for (int i = 0; i < 20; ++i) {
      expect(options.choose(random), 1);
    }
  });

  group('two inequal options', () {
    final options = WeightedOptions<int>([4, 1], (i) => i.toDouble());
    final random = MockRandom();

    test('0.0 returns the less likely', () {
      when(random.nextDouble()).thenReturn(0.0);
      expect(options.choose(random), 1);
    });

    test('1.0 returns the more likely', () {
      when(random.nextDouble()).thenReturn(1.0);
      expect(options.choose(random), 4);
    });

    test('0.5 returns the more likely', () {
      when(random.nextDouble()).thenReturn(0.5);
      expect(options.choose(random), 4);
    });

    test('0.2 returns the less likely', () {
      when(random.nextDouble()).thenReturn(0.2);
      expect(options.choose(random), 1);
    });

    test('0.1999999 returns the less likely', () {
      when(random.nextDouble()).thenReturn(0.1999999);
      expect(options.choose(random), 1);
    });

    test('0.20000001 returns the more likely', () {
      when(random.nextDouble()).thenReturn(0.20000001);
      expect(options.choose(random), 4);
    });
  });

  group('two equal options', () {
    final options = WeightedOptions<int>([1, 2], (i) => 1.0);
    final random = MockRandom();

    test('0.0 returns one', () {
      when(random.nextDouble()).thenReturn(0.0);
      expect(options.choose(random), 1);
    });

    test('0.499999 returns the same one', () {
      when(random.nextDouble()).thenReturn(0.4999999);
      expect(options.choose(random), 1);
    });

    test('0.5 returns the same one', () {
      when(random.nextDouble()).thenReturn(0.5);
      expect(options.choose(random), 1);
    });

    test('0.5000001 returns the other', () {
      when(random.nextDouble()).thenReturn(0.500000001);
      expect(options.choose(random), 2);
    });

    test('1.0 returns the other', () {
      when(random.nextDouble()).thenReturn(1.0);
      expect(options.choose(random), 2);
    });
  });

  group('four equal options', () {
    final options = WeightedOptions<int>([1, 2, 3, 4], (i) => 1.0);
    final random = MockRandom();

    test('get the first', () {
      when(random.nextDouble()).thenReturn(0.0);
      expect(options.choose(random), 1);
      when(random.nextDouble()).thenReturn(0.24999999);
      expect(options.choose(random), 1);
      when(random.nextDouble()).thenReturn(0.25);
      expect(options.choose(random), 1);
    });

    test('get the second', () {
      when(random.nextDouble()).thenReturn(0.25000001);
      expect(options.choose(random), 2);
      when(random.nextDouble()).thenReturn(0.4999999);
      expect(options.choose(random), 2);
      when(random.nextDouble()).thenReturn(0.5);
      expect(options.choose(random), 2);
    });

    test('get the third', () {
      when(random.nextDouble()).thenReturn(0.5000001);
      expect(options.choose(random), 3);
      when(random.nextDouble()).thenReturn(0.74999999);
      expect(options.choose(random), 3);
      when(random.nextDouble()).thenReturn(0.75);
      expect(options.choose(random), 3);
    });

    test('get the fourth', () {
      when(random.nextDouble()).thenReturn(0.75000001);
      expect(options.choose(random), 4);
      when(random.nextDouble()).thenReturn(0.999999);
      expect(options.choose(random), 4);
      when(random.nextDouble()).thenReturn(1.0);
      expect(options.choose(random), 4);
    });
  });

  group('three inequal options', () {
    final options = WeightedOptions<int>([1, 3, 4], (i) => i.toDouble());
    final random = MockRandom();

    test('get the first', () {
      when(random.nextDouble()).thenReturn(0.0);
      expect(options.choose(random), 1);
      when(random.nextDouble()).thenReturn(0.124999);
      expect(options.choose(random), 1);
      when(random.nextDouble()).thenReturn(0.125);
      expect(options.choose(random), 1);
    });

    test('get the second', () {
      when(random.nextDouble()).thenReturn(0.125000001);
      expect(options.choose(random), 3);
      when(random.nextDouble()).thenReturn(0.4999999);
      expect(options.choose(random), 3);
      when(random.nextDouble()).thenReturn(0.5);
      expect(options.choose(random), 3);
    });

    test('get the third', () {
      when(random.nextDouble()).thenReturn(0.5000001);
      expect(options.choose(random), 4);
      when(random.nextDouble()).thenReturn(0.999999);
      expect(options.choose(random), 4);
      when(random.nextDouble()).thenReturn(1.0);
      expect(options.choose(random), 4);
    });
  });

  test('binary sort below pivot', () {
    int sum = 10000;
    for (int i = 1; i < 40; ++i) {
      sum += i;
      final options = WeightedOptions<int>(
          Iterable.generate(i, (n) => n + 1).toList()..add(10000),
          (i) => i.toDouble());
      final random = MockRandom();

      var additiveSum = 0.0;
      for (var n = 1; n < i; ++n) {
        when(random.nextDouble()).thenReturn(additiveSum + 0.0000001);
        expect(options.choose(random), n);
        additiveSum += n / sum;
        when(random.nextDouble()).thenReturn(additiveSum - 0.0000001);
        expect(options.choose(random), n);
      }
    }
  });

  test('binary sort above pivot', () {
    for (int i = 0; i < 40; ++i) {
      final options = WeightedOptions<int>(
          Iterable.generate(i * 2 + 1, (n) => 10000 - i + n).toList(),
          (i) => i.toDouble());
      final random = MockRandom();
      var sum = options.options.reduce((a, b) => a + b).toDouble();
      var additiveSum = options.options
              .where((a) => a <= 10000)
              .reduce((a, b) => a + b)
              .toDouble() /
          sum;

      for (int n = 10001; n < 10000 + i; ++n) {
        when(random.nextDouble()).thenReturn(additiveSum + 0.0000001);
        expect(options.choose(random), n);
        additiveSum += n / sum;
        when(random.nextDouble()).thenReturn(additiveSum - 0.0000001);
        expect(options.choose(random), n);
      }
    }
  });
}

class MockRandom extends Mock implements Random {}
