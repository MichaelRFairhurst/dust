// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:args/args.dart';
import 'package:dust/src/coverage_tracker.dart';
import 'package:dust/src/driver.dart';
import 'package:dust/src/failure_library.dart';
import 'package:dust/src/failure_persistence.dart';
import 'package:dust/src/input_result.dart';
import 'package:dust/src/isolate_mutator.dart';
import 'package:dust/src/mutator.dart';
import 'package:dust/src/mutators.dart';
import 'package:dust/src/path_canonicalizer.dart';
import 'package:dust/src/path_scorer.dart';
import 'package:dust/src/seed_candidate.dart';
import 'package:dust/src/seed_library.dart';
import 'package:dust/src/seed_persistence.dart';
import 'package:dust/src/simplify/contains_constraint.dart';
import 'package:dust/src/simplify/exact_paths_constraint.dart';
import 'package:dust/src/simplify/fewer_paths_constraint.dart';
import 'package:dust/src/simplify/output_constraint.dart';
import 'package:dust/src/simplify/simplifier.dart';
import 'package:dust/src/simplify/simplifier.dart';
import 'package:dust/src/simplify/subset_paths_constraint.dart';
import 'package:dust/src/simplify/succeeded_constraint.dart';
import 'package:dust/src/stats.dart';
import 'package:dust/src/stats_collector.dart';
import 'package:dust/src/vm_controller.dart';
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
    ..addOption('path_sensitivity',
        abbr: 'e',
        help: 'The sensitivity of preferring fewer more unique paths vs more'
            ' less unique paths',
        defaultsTo: '2.0')
    ..addFlag('compress_paths',
        abbr: 'o',
        help: 'Compress path IDs (uses less memory but is not reversible)')
    ..addMultiOption('seed',
        abbr: 's',
        help: 'An initial seed (allows multiple)',
        splitCommas: false)
    ..addOption('seed_dir',
        abbr: 'd', help: 'A directory containing input seeds')
    ..addOption('corpus_dir',
        abbr: 'c', help: 'A directory containing output seeds')
    ..addOption('failure_dir',
        abbr: 'f', help: 'A directory to record failures')
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
    ..addOption('count',
        abbr: 'n',
        help: 'How many fuzz cases to run. -1 is no limit',
        defaultsTo: '-1')
    ..addFlag('simplify',
        abbr: 'l',
        help: 'Whether to simplify input & discovered seeds.',
        defaultsTo: true)
    ..addFlag('snapshot',
        abbr: 'a',
        help: 'Whether to generate a snapshot before fuzzing. Defaults to true'
            ' for scripts that end in .dart',
        defaultsTo: null)
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
          ..addFlag('constraint_same_output')
          ..addFlag('constraint_failed', defaultsTo: true)
          ..addMultiOption('constraint_output_contains')
          ..addFlag('snapshot',
              abbr: 'a',
              help:
                  'Whether to generate a snapshot before fuzzing. Defaults to true'
                  ' for scripts that end in .dart',
              defaultsTo: null));

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

    var script = args.rest[0];

    int batchSize;
    int vms;
    int port;
    int statsInterval;
    int timeout;
    int count;
    double pathSensitivity;
    try {
      batchSize = int.parse(args['batch_size']);
      vms = int.parse(args['vm_count']);
      port = int.parse(args['vm_starting_port']);
      pathSensitivity = double.parse(args['path_sensitivity']);
      statsInterval = int.parse(args['stats_interval']);
      timeout = int.parse(args['timeout']);
      count = int.parse(args['count']);
    } catch (e) {
      print('invalid specified argument: $e');
      _usageAndExit();
    }

    final seeds = (args['seed'] as List<String>)
        .map((seed) => SeedCandidate.forText(seed))
        .toList();
    final seedPersistence = SeedPersistence(
        args['corpus_dir'] ?? '$script.corpus', args['seed_dir']);
    seeds.addAll(await seedPersistence.load());

    FailurePersistence failurePersistence;
    if (args['failure_dir'] != null) {
      failurePersistence = FailurePersistence(args['failure_dir']);
      await failurePersistence.load();
    }

    script = await _potentiallySnapshot(script, args);

    final coverageTracker = CoverageTracker();
    List<VmController> vmControllers;
    _CliStats cliStats;
    List<IsolateMutator> isolateMutators;
    try {
      final pathScorer = PathScorer(coverageTracker, pathSensitivity);
      final pathCanonicalizer =
          PathCanonicalizer(compress: args['compress_paths']);
      final seedLibrary = SeedLibrary(pathScorer);
      final failureLibrary = FailureLibrary();
      vmControllers = Iterable.generate(
          vms,
          (i) => VmController(script, port + i, timeout, pathCanonicalizer,
              coverageTracker)).toList();

      await Future.wait(
          vmControllers.map((vmController) => vmController.prestart()));

      final statsCollector =
          StatsCollector(Stats(DateTime.now(), coverageTracker));
      isolateMutators = await _getIsolateMutators(args);
      final mutators = _getMutators(args, isolateMutators, seedLibrary);
      final driver = Driver(seedLibrary, failureLibrary, batchSize,
          vmControllers, mutators, Random(),
          simplify: args['simplify']);
      statsCollector.collectFrom(driver);

      driver.onNewSeed.listen((seed) {
        print('\nNew seed: ${seed.input}');
        seedPersistence.recordToCorpus(seed.input);
      });
      driver.onSeedCandidateProcessed.listen((seed) {
        if (seed.accepted && !seed.inCorpus) {
          print('\nSeed added to corpus: ${seed.userString}');
          seedPersistence.recordToCorpus(seed.input);
        } else if (!seed.accepted) {
          print('\nSeed not added to corpus: ${seed.userString}');
        }
      });
      driver.onSuccess.listen((_) => stdout.write('.'));
      driver.onDuplicateFail.listen((_) => stdout.write('F'));
      driver.onUniqueFail.listen((failure) {
        print('\nFAILURE: ${failure.input}\n${failure.result.errorOutput}');
        failurePersistence?.recordFailure(failure);
        exitCode = 1;
      });
      if (seeds.isEmpty) {
        seeds.add(SeedCandidate.initial());
      }

      cliStats = _CliStats(statsCollector, statsInterval)..run();
      await driver.run(seeds, count: count);
      cliStats.printStats();
    } finally {
      cliStats?.dispose();
      vmControllers?.forEach((vmController) => vmController.dispose());
      isolateMutators?.forEach((mutator) => mutator.dispose());
    }
  }

  Future<List<IsolateMutator>> _getIsolateMutators(ArgResults args) async {
    final isolateMutators =
        (args['mutator_script'] as List<String>).map((origScript) {
      String script;
      double weight;
      if (origScript.contains(':')) {
        final parts = origScript.split(':');

        script = parts[0];
        weight = double.parse(parts[1]);
      } else {
        weight = 1.0;
        script = origScript;
      }

      return IsolateMutator(script, weight);
    }).toList();
    await Future.wait(isolateMutators.map((isolate) => isolate.start()));
    return isolateMutators;
  }

  WeightedOptions<WeightedMutator> _getMutators(ArgResults args,
      List<IsolateMutator> isolateMutators, SeedLibrary seedLibrary) {
    final mutators = [
      if (args['default_mutators']) ...defaultMutators,
      if (args['default_mutators']) getCrossoverMutator(seedLibrary),
      if (args['default_mutators']) getSpliceMutator(seedLibrary),
      ...isolateMutators
    ];
    if (mutators.isEmpty) {
      print('No mutators specified. Aborting');
      exit(1);
    }
    return WeightedOptions<WeightedMutator>(mutators, (m) => m.weight);
  }

  Future<String> _potentiallySnapshot(String script, ArgResults args) async {
    if (args['snapshot'] ?? script.endsWith('.dart')) {
      final snapshot = '$script.snapshot';
      await VmController.snapshot(script, snapshot);
      return snapshot;
    }

    return script;
  }

  Future<void> _simplify(ArgResults args) async {
    if (args.rest.length != 2) {
      print('expected a script to fuzz and an input to simplify');
      _usageAndExit();
    }

    var script = args.rest[0];
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

    script = await _potentiallySnapshot(script, args);
    final pathCanonicalizer = PathCanonicalizer(compress: false);
    final vmController = VmController(script, port, timeout, pathCanonicalizer);
    try {
      await vmController.prestart();
      final originalResult = await vmController.run(seed);
      if (originalResult.succeeded && args['constraint_failed']) {
        print('Error: seed $seed did not fail, cannot be simplified.');
        return;
      }
      final startTime = DateTime.now();
      final originalInputResult = InputResult(seed, originalResult);
      final simplifier = Simplifier(originalInputResult, vmController, [
        if (args['constraint_failed']) SucceededConstraint.failed(),
        if (args['constraint_subset_paths'])
          SubsetPathsConstraint.ofResult(originalResult),
        if (args['constraint_fewer_paths'])
          FewerPathsConstraint.thanResult(originalResult),
        if (args['constraint_exact_paths'])
          ExactPathsConstraint.sameAs(originalResult),
        if (args['constraint_same_output'])
          OutputConstraint.sameAs(originalResult),
        if (args['constraint_output_contains'] != null)
          for (final output in args['constraint_output_contains'])
            () {
              final constraint = ContainsConstraint(output);
              if (!constraint.accept(originalResult)) {
                throw 'Aborting: original output did not contain "$output."';
              }
              return constraint;
            }(),
      ]);

      final simplification = await simplifier.simplifyToFixedPoint();

      final seconds =
          DateTime.now().difference(startTime).inMilliseconds / 1000;
      if (seed == simplification.input) {
        print('Simplification attempt took $seconds seconds.');
        print('Could not simplify.');
      } else {
        print('Simplified in $seconds seconds.');
        if (simplification.result.errorOutput != originalResult.errorOutput) {
          print(r'''
  Warning: error output was changed during simplification.
  Rerun with --constraint_same_output to prevent this.''');
        }
        print('${simplification.input}');
      }
    } finally {
      await vmController.dispose();
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
  StreamSubscription<void> _timer;
  final StatsCollector _statsCollector;
  final int _intervalSeconds;

  _CliStats(this._statsCollector, this._intervalSeconds);

  void dispose() {
    _timer?.cancel();
  }

  void printStats() {
    final stats = _statsCollector.stats;
    final duration = DateTime.now().difference(stats.startTime);

    String format(double v) => v.toStringAsFixed(2);

    print('''
\n
[=-- Status Report --=]
Time elapsed: ${duration}
Total executions: ${stats.numberOfExecutions} (${format(stats.numberOfExecutions / duration.inSeconds)}/s)
Total seeds: ${stats.numberOfSeeds} (${format(stats.seedRate * 100)}%)
Total failures: ${stats.numberOfFailures} (${format(stats.failureRate * 100)}%)
Visited Paths: ${stats.visitedPaths} (${format(stats.coverageRatio * 100)}%)
Visited Files: ${stats.visitedFiles} (${format(stats.fileCoverageRatio * 100)}%)
''');
  }

  void run() {
    if (_intervalSeconds == 0) {
      return;
    }

    final interval = Duration(seconds: _intervalSeconds);

    _timer = Stream.periodic(interval).listen((_) => printStats());
  }
}
