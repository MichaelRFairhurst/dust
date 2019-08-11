// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:isolate';

import 'package:dust/custom_mutator_helper.dart';
import 'package:fuzz_example_analyzer/syntactically_valid_mutator.dart';

void main(List<String> args, SendPort sendPort) {
  customMutatorHelper(sendPort, syntacticallyValidMutator);
}
