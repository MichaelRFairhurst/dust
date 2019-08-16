// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:math';

import 'package:dust/src/mutators.dart';
import 'package:dust/src/seed.dart';
import 'package:dust/src/seed_library.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

void main() {
  group('addChar', () {
    test('empty string', () {
      final random = MockRandom();
      when(random.nextInt(128 - 31)).thenReturn('a'.codeUnits[0] - 31);
      expect(addChar('', random), 'a');
    });

    test('before one char', () {
      final random = MockRandom();
      when(random.nextInt(2)).thenReturn(0);
      when(random.nextInt(128 - 31)).thenReturn('a'.codeUnits[0] - 31);
      expect(addChar('b', random), 'ab');
    });

    test('after one char', () {
      final random = MockRandom();
      when(random.nextInt(2)).thenReturn(1);
      when(random.nextInt(128 - 31)).thenReturn('a'.codeUnits[0] - 31);
      expect(addChar('b', random), 'ba');
    });

    test('between two chars', () {
      final random = MockRandom();
      when(random.nextInt(3)).thenReturn(1);
      when(random.nextInt(128 - 31)).thenReturn('a'.codeUnits[0] - 31);
      expect(addChar('bb', random), 'bab');
    });

    test('after two chars', () {
      final random = MockRandom();
      when(random.nextInt(3)).thenReturn(2);
      when(random.nextInt(128 - 31)).thenReturn('a'.codeUnits[0] - 31);
      expect(addChar('bb', random), 'bba');
    });
  });

  group('removeChar', () {
    test('empty string', () {
      final random = MockRandom();
      when(random.nextInt(128 - 31)).thenReturn('a'.codeUnits[0] - 31);
      expect(removeChar('', random), 'a');
    });

    test('one char', () {
      final random = MockRandom();
      when(random.nextInt(1)).thenReturn(0);
      expect(removeChar('b', random), '');
    });

    test('first of two chars', () {
      final random = MockRandom();
      when(random.nextInt(2)).thenReturn(0);
      expect(removeChar('ab', random), 'b');
    });

    test('second of two chars', () {
      final random = MockRandom();
      when(random.nextInt(2)).thenReturn(1);
      expect(removeChar('ab', random), 'a');
    });
  });

  group('flipChar', () {
    test('empty string', () {
      final random = MockRandom();
      when(random.nextInt(128 - 31)).thenReturn('a'.codeUnits[0] - 31);
      expect(flipChar('', random), 'a');
    });

    test('one char', () {
      final random = MockRandom();
      when(random.nextInt(1)).thenReturn(0);
      when(random.nextInt(128 - 31)).thenReturn('a'.codeUnits[0] - 31);
      expect(flipChar('b', random), 'a');
    });

    test('first of two chars', () {
      final random = MockRandom();
      when(random.nextInt(2)).thenReturn(0);
      when(random.nextInt(128 - 31)).thenReturn('a'.codeUnits[0] - 31);
      expect(flipChar('bb', random), 'ab');
    });

    test('second of two chars', () {
      final random = MockRandom();
      when(random.nextInt(2)).thenReturn(1);
      when(random.nextInt(128 - 31)).thenReturn('a'.codeUnits[0] - 31);
      expect(flipChar('bb', random), 'ba');
    });

    test('middle of three chars', () {
      final random = MockRandom();
      when(random.nextInt(3)).thenReturn(1);
      when(random.nextInt(128 - 31)).thenReturn('a'.codeUnits[0] - 31);
      expect(flipChar('bbb', random), 'bab');
    });
  });

  group('crossover', () {
    test('no seeds', () {
      final library = MockSeedLibrary();
      final crossover = getCrossoverMutator(library);
      final random = MockRandom();
      when(library.getBatch(1, random)).thenReturn([]);
      when(random.nextInt(4)).thenReturn(3);
      when(random.nextInt(128 - 31)).thenReturn('a'.codeUnits[0] - 31);

      expect(crossover.mutatorFn('foo', random), 'fooa');
    });

    test('empty and empty', () {
      final library = MockSeedLibrary();
      final crossover = getCrossoverMutator(library);
      final random = MockRandom();
      when(library.getBatch(1, random)).thenReturn([Seed('', null)]);
      when(random.nextInt(128 - 31)).thenReturn('a'.codeUnits[0] - 31);

      expect(crossover.mutatorFn('', random), 'a');
    });

    test('1 char each side', () {
      final library = MockSeedLibrary();
      final crossover = getCrossoverMutator(library);
      final random = MockRandom();
      when(library.getBatch(1, random)).thenReturn([Seed('b', null)]);

      expect(crossover.mutatorFn('a', random), 'ab');
    });

    test('split two char lhs', () {
      final library = MockSeedLibrary();
      final crossover = getCrossoverMutator(library);
      final random = MockRandom();
      when(library.getBatch(1, random)).thenReturn([Seed('b', null)]);
      when(random.nextInt(2)).thenReturn(0);

      expect(crossover.mutatorFn('ac', random), 'ab');
    });

    test('append to two char lhs', () {
      final library = MockSeedLibrary();
      final crossover = getCrossoverMutator(library);
      final random = MockRandom();
      when(library.getBatch(1, random)).thenReturn([Seed('b', null)]);
      when(random.nextInt(2)).thenReturn(1);

      expect(crossover.mutatorFn('ac', random), 'acb');
    });

    test('split two char rhs', () {
      final library = MockSeedLibrary();
      final crossover = getCrossoverMutator(library);
      final random = MockRandom();
      when(library.getBatch(1, random)).thenReturn([Seed('bc', null)]);
      when(random.nextInt(2)).thenReturn(1);

      expect(crossover.mutatorFn('a', random), 'ac');
    });

    test('append two char rhs', () {
      final library = MockSeedLibrary();
      final crossover = getCrossoverMutator(library);
      final random = MockRandom();
      when(library.getBatch(1, random)).thenReturn([Seed('bc', null)]);
      when(random.nextInt(2)).thenReturn(0);

      expect(crossover.mutatorFn('a', random), 'abc');
    });

    test('empty lhs', () {
      final library = MockSeedLibrary();
      final crossover = getCrossoverMutator(library);
      final random = MockRandom();
      when(random.nextInt(128 - 31)).thenReturn('a'.codeUnits[0] - 31);
      when(library.getBatch(1, random)).thenReturn([Seed('not used', null)]);

      expect(crossover.mutatorFn('', random), 'a');
    });

    test('empty rhs', () {
      final library = MockSeedLibrary();
      final crossover = getCrossoverMutator(library);
      final random = MockRandom();
      when(random.nextInt(128 - 31)).thenReturn('b'.codeUnits[0] - 31);
      when(random.nextInt(2)).thenReturn(1);
      when(library.getBatch(1, random)).thenReturn([Seed('', null)]);

      expect(crossover.mutatorFn('a', random), 'ab');
    });
  });

  group('splice', () {
    test('no seeds', () {
      final library = MockSeedLibrary();
      final splice = getSpliceMutator(library);
      final random = MockRandom();
      when(library.getBatch(1, random)).thenReturn([]);
      when(random.nextInt(4)).thenReturn(3);
      when(random.nextInt(128 - 31)).thenReturn('a'.codeUnits[0] - 31);

      expect(splice.mutatorFn('foo', random), 'fooa');
    });

    test('empty and empty', () {
      final library = MockSeedLibrary();
      final splice = getSpliceMutator(library);
      final random = MockRandom();
      when(library.getBatch(1, random)).thenReturn([Seed('', null)]);
      when(random.nextInt(128 - 31)).thenReturn('a'.codeUnits[0] - 31);

      expect(splice.mutatorFn('', random), 'a');
    });

    test('before 1 char', () {
      final library = MockSeedLibrary();
      final splice = getSpliceMutator(library);
      final random = MockRandom();
      when(library.getBatch(1, random)).thenReturn([Seed('b', null)]);
      when(random.nextInt(2)).thenReturn(0);
      when(random.nextInt(1)).thenReturn(0);

      expect(splice.mutatorFn('a', random), 'ba');
    });

    test('after 1 char', () {
      final library = MockSeedLibrary();
      final splice = getSpliceMutator(library);
      final random = MockRandom();
      when(library.getBatch(1, random)).thenReturn([Seed('b', null)]);
      when(random.nextInt(2)).thenReturn(1);

      expect(splice.mutatorFn('a', random), 'ab');
    });

    test('over first char', () {
      final library = MockSeedLibrary();
      final splice = getSpliceMutator(library);
      final random = MockRandom();
      when(library.getBatch(1, random)).thenReturn([Seed('b', null)]);
      when(random.nextInt(3)).thenReturn(0);
      when(random.nextInt(2)).thenReturn(1);

      expect(splice.mutatorFn('ac', random), 'bc');
    });

    test('over second char', () {
      final library = MockSeedLibrary();
      final splice = getSpliceMutator(library);
      final random = MockRandom();
      when(library.getBatch(1, random)).thenReturn([Seed('b', null)]);
      when(random.nextInt(3)).thenReturn(1);
      when(random.nextInt(2)).thenReturn(1);

      expect(splice.mutatorFn('ac', random), 'ab');
    });

    test('over first two chars', () {
      final library = MockSeedLibrary();
      final splice = getSpliceMutator(library);
      final random = MockRandom();
      when(library.getBatch(1, random)).thenReturn([Seed('d', null)]);
      when(random.nextInt(4)).thenReturn(0);
      when(random.nextInt(3)).thenReturn(2);

      expect(splice.mutatorFn('abc', random), 'dc');
    });

    test('over middle char', () {
      final library = MockSeedLibrary();
      final splice = getSpliceMutator(library);
      final random = MockRandom();
      when(library.getBatch(1, random)).thenReturn([Seed('d', null)]);
      when(random.nextInt(4)).thenReturn(1);
      when(random.nextInt(3)).thenReturn(1);

      expect(splice.mutatorFn('abc', random), 'adc');
    });

    test('over second two chars', () {
      final library = MockSeedLibrary();
      final splice = getSpliceMutator(library);
      final random = MockRandom();
      when(library.getBatch(1, random)).thenReturn([Seed('d', null)]);
      when(random.nextInt(4)).thenReturn(1);
      when(random.nextInt(3)).thenReturn(2);

      expect(splice.mutatorFn('abc', random), 'ad');
    });

    test('in first char', () {
      final library = MockSeedLibrary();
      final splice = getSpliceMutator(library);
      final random = MockRandom();
      when(random.nextInt(4)).thenReturn(1);
      when(random.nextInt(3)).thenReturn(1);
      when(library.getBatch(1, random)).thenReturn([Seed('de', null)]);
      when(random.nextInt(2)).thenReturn(0);
      when(random.nextInt(2)).thenReturn(0);

      expect(splice.mutatorFn('abc', random), 'adc');
    });

    test('in two chars', () {
      final library = MockSeedLibrary();
      final splice = getSpliceMutator(library);
      final random = MockRandom();
      when(random.nextInt(4)).thenReturn(1);
      when(random.nextInt(3)).thenReturn(1);
      when(library.getBatch(1, random)).thenReturn([Seed('defghi', null)]);
      when(random.nextInt(6)).thenReturn(1);
      when(random.nextInt(5)).thenReturn(1);

      expect(splice.mutatorFn('abc', random), 'aefc');
    });

    test('in second char', () {
      final library = MockSeedLibrary();
      final splice = getSpliceMutator(library);
      final random = MockRandom();
      when(random.nextInt(4)).thenReturn(1);
      when(random.nextInt(3)).thenReturn(1);
      when(library.getBatch(1, random)).thenReturn([Seed('de', null)]);
      when(random.nextInt(2)).thenReturn(1);

      expect(splice.mutatorFn('abc', random), 'aec');
    });

    test('empty lhs', () {
      final library = MockSeedLibrary();
      final splice = getSpliceMutator(library);
      final random = MockRandom();
      when(random.nextInt(128 - 31)).thenReturn('a'.codeUnits[0] - 31);
      when(library.getBatch(1, random)).thenReturn([Seed('not used', null)]);

      expect(splice.mutatorFn('', random), 'a');
    });

    test('empty rhs', () {
      final library = MockSeedLibrary();
      final splice = getSpliceMutator(library);
      final random = MockRandom();
      when(random.nextInt(128 - 31)).thenReturn('b'.codeUnits[0] - 31);
      when(random.nextInt(2)).thenReturn(1);
      when(library.getBatch(1, random)).thenReturn([Seed('', null)]);

      expect(splice.mutatorFn('a', random), 'ab');
    });
  });
}

class MockRandom extends Mock implements Random {}

class MockSeedLibrary extends Mock implements SeedLibrary {}
