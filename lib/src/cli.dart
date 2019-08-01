// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'dart:math';

import 'package:args/args.dart';
import 'package:dust/src/controller.dart';
import 'package:dust/src/driver.dart';
import 'package:dust/src/failure.dart';
import 'package:dust/src/failure_library.dart';
import 'package:dust/src/isolate_mutator.dart';
import 'package:dust/src/location_canonicalizer.dart';
import 'package:dust/src/location_scorer.dart';
import 'package:dust/src/mutator.dart';
import 'package:dust/src/mutators.dart';
import 'package:dust/src/seed_library.dart';
import 'package:dust/src/simplifier.dart';
import 'package:dust/src/stats.dart';
import 'package:dust/src/stats_collector.dart';
import 'package:dust/src/weighted_random_choice.dart';
import 'package:pedantic/pedantic.dart';

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
        abbr: 's',
        help: 'An initial seed (allows multiple)',
        splitCommas: false)
    ..addFlag('default_mutators',
        abbr: 'u',
        help: 'Whether to use the default mutators in addition to custom'
            ' mutators',
        defaultsTo: true)
    ..addOption('stats_interval',
        abbr: 'i',
        help: 'The interval (in seconds) to print progress stats. Set to 0 to'
            ' disable.',
        defaultsTo: '120')
    ..addOption('timeout',
        abbr: 't',
        help: 'The maximum duration (in seconds) before a test should be killed'
            ' and considered a fail.',
        defaultsTo: '10')
    ..addMultiOption(
      'mutator_script',
      abbr: 'm',
      help: 'A path to a script, or comma separated path to scripts, that'
          ' perform specialized mutations',
    )
    ..addCommand(
        'simplify',
        ArgParser()
          ..addOption('port',
              abbr: 'p', help: 'The port for the VM', defaultsTo: '7575')
          ..addOption('timeout',
              abbr: 't',
              help: 'The maximum duration (in seconds) before a test should be'
                  ' killed and considered a fail.',
              defaultsTo: '10')
          ..addFlag('constraint_subset_paths')
          ..addFlag('constraint_fewer_paths')
          ..addFlag('constraint_exact_paths')
          ..addFlag('constraint_same_output', defaultsTo: true)
          ..addFlag('constraint_failed', defaultsTo: true));

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
    int statsInterval;
    int timeout;
    double locationSensitivity;
    try {
      batchSize = int.parse(args['batch_size']);
      vms = int.parse(args['vm_count']);
      port = int.parse(args['vm_starting_port']);
      locationSensitivity = double.parse(args['location_sensitivity']);
      statsInterval = int.parse(args['stats_interval']);
      timeout = int.parse(args['timeout']);
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
              vms,
              (i) =>
                  Controller(script, port + i, timeout, locationCanonicalizer))
          .toList();

      await Future.wait(runners.map((runner) => runner.prestart()));

      final statsCollector =
          StatsCollector(ProgramStats(await runners[0].countLocations()));
      final mutators = await _getMutators(args);
      final driver = Driver(
          seedLibrary, failureLibrary, batchSize, runners, mutators, Random());
      statsCollector.collectFrom(driver, locationScorer);

      driver.onNewSeed.listen((seed) => print('\nNew seed: ${seed.input}'));
      driver.onSuccess.listen((_) => stdout.write('.'));
      driver.onDuplicateFail.listen((_) => stdout.write('F'));
      driver.onUniqueFail.listen((failure) =>
          print('\nFAILURE: ${failure.input}\n${failure.result.errorOutput}'));
      final seeds = args['seed'];
      if (seeds.isEmpty) {
        seeds.add('');
      }

      _CliStats()._run(statsCollector, statsInterval);
      await driver.run(seeds);
    } finally {
      runners.forEach((runner) => runner.dispose());
    }
  }

  Future<WeightedOptions<WeightedMutator>> _getMutators(ArgResults args) async {
    final isolateMutators =
        (args['mutator_script'] as List<String>).map((origScript) {
      String script;
      double weight;
      if (origScript.contains(':')) {
        final parts = script.split(':');

        script = parts[0];
        weight = double.parse(parts[1]);
      } else {
        weight = 1.0;
        script = origScript;
      }

      return IsolateMutator(script, weight);
    }).toList();

    await Future.wait(isolateMutators.map((isolate) => isolate.start()));
    final mutators = [
      if (args['default_mutators']) ...defaultMutators,
      ...isolateMutators
    ];
    if (mutators.isEmpty) {
      print('No mutators specified. Aborting');
      exit(1);
    }
    return WeightedOptions<WeightedMutator>(mutators, (m) => m.weight);
  }

  Future<void> _simplify(ArgResults args) async {
    if (args.rest.length != 2) {
      print('expected a script to fuzz and an input to simplify');
      _usageAndExit();
    }

    final script = args.rest[0];
    final seed = args.rest[1];

    int port;
    int timeout;
    try {
      port = int.parse(args['port']);
      timeout = int.parse(args['timeout']);
    } catch (e) {
      print('invalid specified argument: $e');
      _usageAndExit();
    }

    final locationCanonicalizer = LocationCanonicalizer(compress: false);
    final runner = Controller(script, port, timeout, locationCanonicalizer);
    try {
      await runner.prestart();
      final result = await runner.run(seed);
      if (result.succeeded && args['constraint_failed']) {
        print('Error: seed $seed did not fail, cannot be simplified.');
        return;
      }
      // TODO(mfairhurst): this will fail an assert for --no-constraint-failed
      final failure = Failure(seed, await runner.run(seed));
      final simplifier = Simplifier(failure, runner, [
        if (args['constraint_failed']) SimplifierConstraint.failed,
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
      await runner.dispose();
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

class _CliStats {
  void _printStats(StatsCollector statsCollector) {
    final stats = statsCollector.progressStats;
    final duration = DateTime.now().difference(stats.startTime);

    String format(double v) => v.toStringAsFixed(2);

    print('''
\n
[=-- Status Report --=]
Time elapsed: ${duration}
Total executions: ${stats.numberOfExecutions} (${format(stats.numberOfExecutions / duration.inSeconds)}/s)
Total seeds: ${stats.numberOfSeeds} (${format(stats.seedRate * 100)}%)
Total failures: ${stats.numberOfFailures} (${format(stats.failureRate * 100)}%)
Visited Paths: ${stats.visitedPaths}
'''
// TODO(mfairhusrt): Gather correct program coverage to get an accurate ratio.
// (${format(stats.coverageRatio * 100)}%)
        );
  }

  void _run(StatsCollector statsCollector, int intervalSeconds) {
    if (intervalSeconds == 0) {
      return;
    }

    final interval = Duration(seconds: intervalSeconds);

    unawaited(() async {
      while (true) {
        await Future.delayed(interval);
        _printStats(statsCollector);
      }
    }());
  }
}
