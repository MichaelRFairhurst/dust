// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'dart:math';

import 'package:args/args.dart';
import 'package:dust/src/controller.dart';
import 'package:dust/src/failure_library.dart';
import 'package:dust/src/location_scorer.dart';
import 'package:dust/src/seed_library.dart';

import 'driver.dart';

/// Primary class for running the fuzzer on the CLI.
class Cli {
  final _parser = ArgParser()
    ..addFlag('help', abbr: 'h', help: 'print this help')
    ..addOption('vm_count',
        abbr: 'v', help: 'How many VMs to run at once', defaultsTo: '8')
    ..addOption('batch_size',
        abbr: 'b', help: 'How many seeds to generate at once', defaultsTo: '50')
    ..addOption('vm_starting_port',
        abbr: 'p',
        help: 'The base port for VMs (port is incremented by 1 per vm)',
        defaultsTo: '7575')
    ..addOption('location_sensitivity',
        abbr: 'e',
        help: 'The sensitivity of preferring fewer more unique locations vs'
            ' more less unique locations',
        defaultsTo: '2.0')
    ..addMultiOption('seed',
        abbr: 's', help: 'An initial seed (allows multiple)', defaultsTo: ['']);

  /// Run the CLI given the provided arguments.
  Future<void> run(List<String> baseArgs) async {
    ArgResults args;
    try {
      args = _parser.parse(baseArgs);
    } catch (e) {
      print(e);
      _usageAndExit();
    }
    if (args.rest.length != 1) {
      print('expected a script to fuzz');
      _usageAndExit();
    }

    if (args['help']) {
      _usageAndExit();
    }

    final script = args.rest[0];

    int batchSize;
    int vms;
    int port;
    double locationSensitivity;
    try {
      batchSize = int.parse(args['batch_size']);
      vms = int.parse(args['vm_count']);
      port = int.parse(args['vm_starting_port']);
      locationSensitivity = double.parse(args['location_sensitivity']);
    } catch (e) {
      print('invalid specified argument: $e');
      _usageAndExit();
    }

    List<Controller> runners;
    try {
      final locationScorer = LocationScorer(locationSensitivity);
      final seedLibrary = SeedLibrary(locationScorer);
      final failureLibrary = FailureLibrary();
      runners =
          Iterable.generate(vms, (i) => Controller(script, port + i)).toList();
      await Future.wait(runners.map((runner) => runner.prestart()));
      final driver =
          Driver(seedLibrary, failureLibrary, batchSize, runners, Random());

      driver.onNewSeed.listen((seed) => print('\nNew seed: ${seed.input}'));
      driver.onSuccess.listen((_) => stdout.write('.'));
      driver.onDuplicateFail.listen((_) => stdout.write('F'));
      driver.onUniqueFail.listen((failure) =>
          print('\nFAILURE: ${failure.input}\n${failure.result.errorOutput}'));
      await driver.run(args['seed']);
    } finally {
      runners.forEach((runner) => runner.dispose());
    }
  }

  void _usageAndExit() {
    print('usage: fuzz.dart [options] script.dart');
    print(_parser.usage);
    exit(1);
  }
}
