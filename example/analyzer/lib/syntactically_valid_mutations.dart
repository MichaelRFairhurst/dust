// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:math';

import 'package:fuzz_example_analyzer/use_dart_fuzz.dart';

String generateCascade(Random random) {
  final name = 'f${random.nextInt(10)}';
  switch (random.nextInt(4)) {
    case 0:
      return '..f$name';
    case 1:
      final name = 'f${random.nextInt(10)}';
      return '..f$name = ${generateExpr(random)}';
    case 2:
      final name = 'f${random.nextInt(10)}';
      return '..f$name()';
    case 3:
      final name = 'f${random.nextInt(10)}';
      return '..[${generateExpr(random)}] = ${generateExpr(random)}';
  }

  throw 'bad random value';
}

String generateClassDeclaration(Random random) {
  final classname = 'X${random.nextInt(10)}';
  return 'class $classname {}';
}

String generateMember(Random random) {
  switch (random.nextInt(2)) {
    case 0:
      return generateVarDeclaration(random);
    case 1:
      return generateMethod(random);
  }

  throw 'got wrong random value';
}

String generateTopLevel(Random random) {
  switch (random.nextInt(3)) {
    case 0:
      return generateClassDeclaration(random);
    case 1:
      return generateVarDeclaration(random);
    case 2:
      return generateMethod(random);
  }

  throw 'got wrong random value';
}
