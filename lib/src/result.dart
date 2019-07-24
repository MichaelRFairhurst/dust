// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dust/src/location.dart';

class Result {
  final String errorOutput;
  final Duration timeElapsed;
  final List<Location> locations;

  Result(this.timeElapsed, this.locations) : errorOutput = null;

  Result.failed(this.errorOutput, this.timeElapsed, this.locations);

  bool get succeeded => errorOutput == null;
}
