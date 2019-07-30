// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:math';

import 'package:dust/src/weighted_random_choice.dart';

/// Perform a random mutation on the [input] String.
///
/// For better performance, use [mutateMany] when possible, because
/// WeightedOptions.chooseMany is more performant than WeightedOptions.choose().
FutureOr<String> mutate(String input, Random random,
        WeightedOptions<WeightedMutator> mutators) =>
    mutators.choose(random).mutatorFn(input, random);

/// Perform a random mutation on each of the input Strings.
///
/// More performant than calling [mutate] n times, because
/// WeightedOptions.chooseMany is more performant than WeightedOptions.choose().
Future<List<String>> mutateMany(List<String> inputs, Random random,
    WeightedOptions<WeightedMutator> mutators) async {
  final which = mutators.chooseMany(inputs.length, random);
  final results = List(inputs.length);
  for (var i = 0; i < inputs.length; ++i) {
    results[i] = await which[i].mutatorFn(inputs[i], random);
  }
  return results;
}

/// The function signature of a mutator for mutation-based fuzzing.
typedef Mutator = FutureOr<String> Function(String, Random);

/// A Mutator with a weight for probabilistic weighted selection.
abstract class WeightedMutator {
  /// The function that is weighted and performs the mutation.
  Mutator get mutatorFn;

  /// The weight for probability of selecting this mutator.
  double get weight;
}
