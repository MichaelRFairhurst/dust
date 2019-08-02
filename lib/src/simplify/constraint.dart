// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dust/src/vm_result.dart';

/// A class to constrain what is acceptable as a simplification of a result.
abstract class Constraint {
  /// Whether the constraint is satisfied for the [result].
  bool accept(VmResult result);
}
