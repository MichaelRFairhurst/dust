// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:analyzer/src/dart/analysis/driver.dart';
import 'package:analyzer/src/dart/analysis/performance_logger.dart';
import 'package:analyzer/src/generated/sdk.dart';
import 'package:fuzz_example_analyzer/syntactically_valid_mutations.dart';

import 'file:/home/mfairhurst/dart/sdk/runtime/tools/dartfuzz/dartfuzz.dart';

String generateExpr(Random random) {
  final mockFile = MockFile();
  final fuzz = DartFuzz(random.nextInt(4294967296), true, mockFile,
      empty: true, maxDepth: random.nextInt(2))
    ..init();
  fuzz.emitExpr(0, fuzz.getType());
  return mockFile.str;
}

String generateMethod(Random random) {
  final mockFile = MockFile();
  final methodName = 'f${random.nextInt(10)}';
  final fuzz = DartFuzz(random.nextInt(4294967296), true, mockFile, empty: true)
    ..init();
  final types = [fuzz.getType()];
  fuzz.emitMethods(methodName, [types]);
  return mockFile.str;
}

String generateStatement(Random random) {
  if (random.nextBool()) {
    final mockFile = MockFile();
    final fuzz = DartFuzz(random.nextInt(4294967296), true, mockFile,
        empty: true, maxDepth: random.nextInt(2))
      ..init()
      ..emitStatement(0);
    return mockFile.str;
  } else {
    return generateMember(random);
  }
}

String generateVarDeclaration(Random random) {
  final mockFile = MockFile();
  final varname = 'var${random.nextInt(10)}';
  final fuzz = DartFuzz(random.nextInt(4294967296), true, mockFile,
      empty: true, maxDepth: 0)
    ..init();
  fuzz.emitVarDecls(varname, [fuzz.getType()]);
  return mockFile.str;
}

class MockFile implements RandomAccessFile {
  String str = '';

  @override
  dynamic noSuchMethod(Invocation invocation) {
    super.noSuchMethod(invocation);
  }

  @override
  void writeStringSync(String str, {Encoding encoding: utf8}) {
    this.str += str;
  }
}
