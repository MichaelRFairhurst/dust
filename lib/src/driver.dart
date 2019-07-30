// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:dust/src/controller.dart';
import 'package:dust/src/failure.dart';
import 'package:dust/src/failure_library.dart';
import 'package:dust/src/mutator.dart';
import 'package:dust/src/mutators.dart';
import 'package:dust/src/pool.dart';
import 'package:dust/src/seed.dart';
import 'package:dust/src/seed_library.dart';
import 'package:dust/src/weighted_random_choice.dart';

/// Drives the main fuzz testing loop.
///
/// Meant to be platform-agnostic, but otherwise do the bulk of the wiring of
/// the fuzz tester workflow.
class Driver {
  final SeedLibrary _seeds;
  final FailureLibrary _failures;
  final Random _random;
  final List<Controller> _runners;
  final WeightedOptions<WeightedMutator> _mutators;
  final int _batchSize;

  final _successStreamCtrl = StreamController<void>();
  final _newSeedStreamCtrl = StreamController<Seed>();
  final _uniqueFailStreamCtrl = StreamController<Failure>();
  final _duplicateFailStreamCtrl = StreamController<Failure>();

  /// Construct a Driver to run fuzz testing.
  Driver(this._seeds, this._failures, this._batchSize, this._runners,
      this._mutators, this._random);

  /// Notifications for all non-unique fuzz [Failure] cases.
  Stream<Failure> get onDuplicateFail => _duplicateFailStreamCtrl.stream;

  /// Notifications for when new [Seed]s are discovered.
  Stream<Seed> get onNewSeed => _newSeedStreamCtrl.stream;

  /// Notifications for when cases pass without error.
  Stream<void> get onSuccess => _successStreamCtrl.stream;

  /// Notifications fo new and unique fuzz [Failure] cases.
  Stream<Failure> get onUniqueFail => _uniqueFailStreamCtrl.stream;

  /// Begin running the [Driver]
  Future<void> run(List<String> seeds) async {
    // run initial seeds
    await Pool<Controller, String>(_runners, _preseed,
            handleError: (controller, seed, error) =>
                throw Exception('failed to preseed $seed: $error'))
        .consume(Queue.from(seeds));

    final pool = Pool<Controller, Seed>(_runners, _runCase,
        handleError: (controller, seed, error) async {
      // TODO(mfairhurst): report this some other way.
      print('error with ${seed.input}: $error');
      if (controller.isConnected) {
        await controller.dispose();
      }
      await controller.prestart();
      // Don't re-add item. It is randomly generated, and we've printed it. So
      // it is safer to drop. Otherwise, if we weren't careful, a single bad
      // item could deadlock the queue.
      return false;
    });

    while (true) {
      final batch = _seeds.getBatch(_batchSize, _random);

      await pool.consume(Queue.from(batch));
    }
  }

  Future<void> _preseed(Controller runner, String seed) async {
    final result = await runner.run(seed);
    _seeds.report(seed, result);
  }

  Future<void> _runCase(Controller runner, Seed seed) async {
    final input = await mutate(seed.input, _random, _mutators);
    final result = await runner.run(input);
    if (!result.succeeded) {
      final failure = Failure(input, result);
      final previousFailure = _failures.report(failure);
      if (previousFailure == null) {
        _uniqueFailStreamCtrl.add(failure);
      } else {
        _duplicateFailStreamCtrl.add(failure);
      }
    }

    _successStreamCtrl.add(null);
    final newSeed = _seeds.report(input, result);
    if (newSeed != null) {
      _newSeedStreamCtrl.add(newSeed);
    }
  }
}
