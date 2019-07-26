// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dust/src/location.dart';
import 'package:test/test.dart';

void main() {
  final location = Location('/lib/foo.dart', 3);

  test("a location's toString is its source colon id", () {
    expect(location.toString(), '/lib/foo.dart:3');
  });

  test('a location is equal when source and id are equal', () {
    final equalLocation = Location('/lib/foo.dart', 3);
    expect(location, equalLocation);
  });

  test('a location is not equal when source and id are not equal', () {
    final wrongSource = Location('/lib/bar.dart', 3);
    final wrongId = Location('/lib/foo.dart', 4);
    final wrongSourceId = Location('/lib/bar.dart', 4);
    expect(location, isNot(wrongSource));
    expect(location, isNot(wrongId));
    expect(location, isNot(wrongSourceId));
  });

  test("a location's hashcode is equal when source and id are equal", () {
    final equalLocation = Location('/lib/foo.dart', 3);
    expect(location.hashCode, equalLocation.hashCode);
  });

  test('known cases of different hashCodes', () {
    final wrongSource = Location('/lib/bar.dart', 3);
    final wrongId = Location('/lib/foo.dart', 4);
    final wrongSourceId = Location('/lib/bar.dart', 4);
    expect(location.hashCode, isNot(wrongSource.hashCode));
    expect(location.hashCode, isNot(wrongId.hashCode));
    expect(location.hashCode, isNot(wrongSourceId.hashCode));
  });
}
