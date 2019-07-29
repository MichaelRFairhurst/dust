// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'dart:math';

import 'package:args/args.dart';
import 'package:dust/src/controller.dart';
import 'package:dust/src/failure.dart';
import 'package:dust/src/failure_library.dart';
import 'package:dust/src/location_canonicalizer.dart';
import 'package:dust/src/location_scorer.dart';
import 'package:dust/src/seed_library.dart';
import 'package:dust/src/simplifier.dart';

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
    ..addFlag('compress_locations',
        abbr: 'c',
        help: 'Compress location IDs (uses less memory but is not reversible)')
    ..addMultiOption('seed',
        abbr: 's', help: 'An initial seed (allows multiple)', defaultsTo: [''])
    ..addCommand(
        'simplify',
        ArgParser()
          ..addOption('port',
              abbr: 'p', help: 'The port for the VM', defaultsTo: '7575')
          ..addFlag('constraint_subset_paths')
          ..addFlag('constraint_fewer_paths')
          ..addFlag('constraint_exact_paths')
          ..addFlag('constraint_same_output', defaultsTo: true));

  /// Run the CLI given the provided arguments.
  Future<void> run(List<String> baseArgs) async {
    ArgResults args;
    try {
      args = _parser.parse(baseArgs);
    } catch (e) {
      print(e);
      _usageAndExit();
    }
    if (args.command?.name == 'simplify') {
      await _simplify(args.command);
      return;
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
      final locationCanonicalizer =
          LocationCanonicalizer(compress: args['compress_locations']);
      final seedLibrary = SeedLibrary(locationScorer);
      final failureLibrary = FailureLibrary();
      runners = Iterable.generate(
              vms, (i) => Controller(script, port + i, locationCanonicalizer))
          .toList();
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

  Future<void> _simplify(ArgResults args) async {
    if (args.rest.length != 2) {
      print('expected a script to fuzz and an input to simplify');
      _usageAndExit();
    }

    final script = args.rest[0];
    final seed = args.rest[1];

    int port;
    try {
      port = int.parse(args['port']);
    } catch (e) {
      print('invalid specified argument: $e');
      _usageAndExit();
    }

    final locationCanonicalizer = LocationCanonicalizer(compress: false);
    final runner = Controller(script, port, locationCanonicalizer);
    try {
      await runner.prestart();
      final result = await runner.run(seed);
      if (result.succeeded) {
        print('Error: seed $seed did not fail, cannot be simplified.');
        return;
      }
      final failure = Failure(seed, await runner.run(seed));
      final simplifier = Simplifier(failure, runner, [
        SimplifierConstraint.failed,
        if (args['constraint_subset_paths']) SimplifierConstraint.subsetPaths,
        if (args['constraint_fewer_paths']) SimplifierConstraint.fewerPaths,
        if (args['constraint_exact_paths']) SimplifierConstraint.exactPaths,
        if (args['constraint_same_output']) SimplifierConstraint.sameOutput,
      ]);

      final simplification = await simplifier.simplify();

      if (seed == simplification) {
        print('Could not simplify.');
      } else {
        print('Simplified.\n$simplification');
      }
    } finally {
      runner.dispose();
    }
  }

  void _usageAndExit([String command]) {
    print('usage: pub global run dust [options] script.dart');
    print(_parser.usage);
    print('');
    print('   or: pub global run dust simplify [options] script.dart input');
    print(_parser.commands['simplify'].usage);
    exit(1);
  }
}
