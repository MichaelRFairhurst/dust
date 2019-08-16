// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:math';

import 'package:dust/src/mutators.dart';
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
}

class MockRandom extends Mock implements Random {}
