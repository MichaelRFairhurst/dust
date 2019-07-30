// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:isolate';
import 'dart:math';

import 'package:dust/custom_mutator_helper.dart';
import 'package:front_end/src/scanner/token.dart' show Keyword;

void main(List<String> args, SendPort sendPort) {
  final random = Random();

  customMutatorHelper(sendPort, (str) {
    final pos = random.nextInt(str.length + 1);
    return str.replaceRange(
        pos, pos, Keyword.values[random.nextInt(Keyword.values.length)].lexeme);
  });
}
