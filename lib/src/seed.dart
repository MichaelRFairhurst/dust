// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dust/src/result.dart';

/// A special input case value which executed new code paths.
///
/// These seeds are kept, scored, randomly chosen, and mutated in search of new
/// seeds.
class Seed {
  /// The [String] value used when fuzzing that discovered this seed.
  final String input;

  /// The most recently calculated score indicating the usefulness of this seed.
  double score;

  /// The results of the first run of this seed, used to calculate its [score].
  final Result initialResult;

  /// Create an unscored seed.
  Seed(this.input, this.initialResult);
}
