// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:math';

/// Add a single random char to a random position in the [input] string.
String addChar(String input, Random random) {
  final newchar = _randomChar(random);
  final charpos = _randomPos(input, random, true);
  return input.replaceRange(charpos, charpos, newchar);
}

/// Change a single random char to a new random char in the [input] string.
String flipChar(String input, Random random) {
  if (input.isEmpty) {
    return addChar(input, random);
  }

  final newchar = _randomChar(random);
  final charpos = _randomPos(input, random);
  return input.replaceRange(charpos, charpos + 1, newchar);
}

/// Perform a random mutation on the [input] String.
String mutate(String input, Random random) {
  switch (random.nextInt(3)) {
    case 0:
      return addChar(input, random);
    case 1:
      return flipChar(input, random);
    case 2:
      return removeChar(input, random);
  }

  throw Exception('should not be possible');
}

/// Remove a single random char in the [input] string.
String removeChar(String input, Random random) {
  if (input.isEmpty) {
    return addChar(input, random);
  }
  final charpos = _randomPos(input, random);
  return input.replaceRange(charpos, charpos + 1, '');
}

String _randomChar(Random random) =>
    String.fromCharCode(random.nextInt(128 - 31) + 31);

int _randomPos(String s, Random random, [bool inclusive = false]) =>
    s.isEmpty ? 0 : random.nextInt(s.length + (inclusive ? 1 : 0));
