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
FutureOr<String> mutate(
    String input, Random random, WeightedOptions<WeightedMutator> mutators,
    {int stacks = 3}) async {
  var result = input;
  for (var i = random.nextInt(stacks) + 1; i > 0; --i) {
    result = await mutators.choose(random).mutatorFn(result, random);
  }
  return result;
}

/// Perform a random mutation on each of the input Strings.
///
/// More performant than calling [mutate] n times, because
/// WeightedOptions.chooseMany is more performant than WeightedOptions.choose().
Future<List<String>> mutateMany(List<String> inputs, Random random,
    WeightedOptions<WeightedMutator> mutators,
    {int stacks = 3}) async {
  final chosenStacks =
      Iterable.generate(inputs.length, (_) => random.nextInt(stacks) + 1)
          .toList();
  final totalMutators = chosenStacks.reduce((a, b) => a + b);
  final chosenMutators = mutators.chooseMany(totalMutators, random);
  final results = List(inputs.length);
  for (var i = 0; i < inputs.length; ++i) {
    results[i] = inputs[i];
    for (var stackIndex = 0, mutatorIndex = 0;
        stackIndex < chosenStacks[i];
        stackIndex++, mutatorIndex++) {
      results[i] =
          await chosenMutators[mutatorIndex].mutatorFn(results[i], random);
    }
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
