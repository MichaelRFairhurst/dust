// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dust/src/result.dart';

class Failure {
  final String input;
  final Result result;

  Failure(this.input, this.result) {
    assert(!result.succeeded);
  }
}
