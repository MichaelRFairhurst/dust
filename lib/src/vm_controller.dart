// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dust/src/path.dart';
import 'package:dust/src/path_canonicalizer.dart';
import 'package:dust/src/vm_result.dart';
import 'package:path/path.dart' as path;
import 'package:pedantic/pedantic.dart';
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

/// A class to start a VM, connect to its service, and control its fuzz cases.
///
/// A controller should be [prestart]ed, and [dispose]d when no longer needed.
///
/// Controllers will start `bin/controller.dart` in a new VM with an observatory
/// port open. The controller script and controller class communicate with JSON
/// over stdin/stdout. The controller script takes each input and starts an
/// isolate named 'fuzz_target'. This class collects the instrumentation data
/// from that isolate before closing it, at which point the controller script
/// reports back any failure information.
class VmController {
  final String _script;
  final String _host = 'localhost';
  final int _port;
  final int _timeout;
  final PathCanonicalizer _pathCanonicalizer;
  int _exitCode;
  VmService _serviceClient;
  Process _process;
  DateTime _startTime;
  StringBuffer _outputBuffer;
  StringBuffer _stdErrBuffer;
  Future<void> _processExit;
  Duration _timeElapsed;

  /// Construct a [VmController] from a script and a port.
  VmController(
      this._script, this._port, this._timeout, this._pathCanonicalizer);

  /// Check if this VM is connected.
  bool get isConnected => _serviceClient != null;

  /// Kill the process & close the service connection.
  Future<void> dispose() async {
    try {
      _serviceClient?.dispose();
      _process?.kill();
      _process = null;
      _serviceClient = null;
      await _processExit;
    } finally {
      _process?.kill();
      _process = null;
      _serviceClient = null;
    }
  }

  /// Start the VM for this controller so that its ready to run cases.
  Future<void> prestart() async {
    _exitCode = null;
    await _startProcess();
    _serviceClient = await _connect();
  }

  /// Run an individual case on a VM controller that's already been prestarted.
  Future<VmResult> run(String input, {bool readCoverage = true}) async {
    final fuzzIsolate = await _preRunCase(input);

    final paths = readCoverage ? await _getPath(fuzzIsolate) : null;
    await _serviceClient.resume(fuzzIsolate.id);
    await _fuzzIsolateDead();

    final jsonOut = await _finalizeOutput();

    final bool succeeded = jsonOut['success'];
    if (succeeded) {
      return VmResult(_timeElapsed, paths);
    } else {
      return VmResult.failed(jsonOut['output'], _timeElapsed, paths);
    }
  }

  Future<VmService> _connect() async {
    final _serviceClient = await _exponentialBackoff(
        () => vmServiceConnect(_host, _port, log: _StdoutLog()),
        (client) => client != null);
    unawaited(_serviceClient.streamListen(EventStreams.kDebug));
    _serviceClient.onDebugEvent.listen((event) {
      if (event.kind == 'PauseExit') {
        if (event.isolate.name == 'fuzz_target') {
          _timeElapsed = DateTime.now().difference(_startTime);
        } else {
          _serviceClient.resume(event.isolate.id);
        }
      }
    });

    // Wait until the main isolate starts, to force an exception now if
    // observatory can't start.
    await _exponentialBackoff(
        () async => (await _serviceClient.getVM())
            .isolates
            .singleWhere((isolate) => isolate.name == 'main'),
        (isolate) => isolate != null);

    return _serviceClient;
  }

  Future<T> _exponentialBackoff<T>(
      Future<T> Function() action, bool Function(T) accept,
      {Duration limit = const Duration(seconds: 5)}) async {
    var wait = const Duration(milliseconds: 1);
    final start = DateTime.now();

    dynamic reason;

    while (DateTime.now().difference(start) < limit) {
      if (_exitCode != null) {
        throw Exception('VM at $_port exited with code $_exitCode:\n'
            '$_outputBuffer\n'
            '$_stdErrBuffer');
      }

      try {
        final result = await action();
        if (accept(result)) {
          return result;
        }
        reason = 'not accepted';
      } catch (e, st) {
        reason = '$e $st';
      }
      await Future.delayed(wait);
      wait += const Duration(milliseconds: 1);
    }

    throw Exception('$limit tries exceeded: $reason');
  }

  /// Read the json output from the main isolate.
  Future<Map<String, dynamic>> _finalizeOutput() async => _exponentialBackoff(
      () async => jsonDecode(_outputBuffer.toString().trim()), (_) => true);

  Future<Isolate> _fuzzIsolateComplete() async {
    final isolateRef = await _exponentialBackoff(
        () async => (await _serviceClient.getVM())
            .isolates
            .singleWhere((isolate) => isolate.name == 'fuzz_target'),
        (isolate) => isolate != null);

    final isolate = await _exponentialBackoff(
        () async => _serviceClient.getIsolate(isolateRef.id),
        (isolate) => isolate == null || isolate.pauseEvent.kind == 'PauseExit',
        limit: Duration(seconds: _timeout + 2));

    _timeElapsed ??= DateTime.now().difference(_startTime);
    return isolate;
  }

  Future<void> _fuzzIsolateDead() async {
    await _exponentialBackoff(
        () async => (await _serviceClient.getVM()).isolates,
        (isolates) =>
            !isolates.any((isolate) => isolate.name == 'fuzz_target'));
  }

  Future<List<Path>> _getPath(Isolate isolate) async {
    final report = await _serviceClient
        .getSourceReport(isolate.id, [SourceReportKind.kCoverage]);
    return report.ranges
        .where((range) => range.coverage != null)
        .expand((range) {
      final uri = _pathCanonicalizer
          .processScriptUri(report.scripts[range.scriptIndex].uri);
      return range.coverage.hits.map((id) => _pathCanonicalizer.canonicalize(
            Path(
              uri,
              id,
            ),
          ));
    }).toList();
  }

  /// Execute the [input] on the vm, but then pause to collect instrumentation.
  Future<Isolate> _preRunCase(String input) async {
    _startTime = DateTime.now();
    _outputBuffer = StringBuffer();
    _process.stdin.writeln(jsonEncode(input));
    return _fuzzIsolateComplete();
  }

  Future<void> _startProcess() async {
    final sdk = path.dirname(path.dirname(Platform.resolvedExecutable));

    _process = await Process.start('$sdk/bin/dart', [
      '--pause_isolates_on_exit',
      '--enable-asserts',
      '--enable-vm-service=$_port',
      '--disable-service-auth-codes',
      path.join(Platform.environment['HOME'],
          '.pub-cache/global_packages/dust/bin/controller.dart.snapshot.dart2'),
      _script,
      '$_timeout',
    ]);

    final vmCompleter = Completer();
    unawaited(_process.exitCode.then((code) {
      _exitCode = code;
      vmCompleter.complete();
      _serviceClient?.dispose();
      _serviceClient = null;
    }));
    _processExit = vmCompleter.future;

    _outputBuffer = StringBuffer();
    _process.stdout
        .transform(utf8.decoder)
        .listen((output) => _outputBuffer?.write(output));

    _stdErrBuffer = StringBuffer();
    _process.stderr.transform(utf8.decoder).listen(_stdErrBuffer.write);

    // Ensure observatory starts up properly.
    // TODO: Try a different port on failure.
    try {
      await _exponentialBackoff(
          () async => _outputBuffer.toString(),
          (output) =>
              output.contains('listening on') && output.contains(':$_port/'));
    } catch (_) {
      throw 'Observatory did not start on $_port\noutput:\n$_outputBuffer';
    }
  }

  /// Generate a snapshot for the script, for faster fuzzing.
  static Future<void> snapshot(String script, String snapshotPath) async {
    final sdk = path.dirname(path.dirname(Platform.resolvedExecutable));

    final result = await Process.run('$sdk/bin/dart', [
      '--snapshot=$snapshotPath',
      '--snapshot-kind=kernel',
      script,
    ]);

    if (result.exitCode != 0) {
      throw '${result.stdout}${result.stderr}';
    }
  }
}

class _StdoutLog extends Log {
  @override
  void severe(String message) => print(message);

  @override
  void warning(String message) => print(message);
}
