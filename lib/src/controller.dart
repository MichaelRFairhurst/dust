// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dust/src/location.dart';
import 'package:dust/src/location_canonicalizer.dart';
import 'package:dust/src/result.dart';
import 'package:path/path.dart' as path;
import 'package:pedantic/pedantic.dart';
import 'package:vm_service_lib/vm_service_lib.dart';
import 'package:vm_service_lib/vm_service_lib_io.dart';

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
class Controller {
  final String _script;
  final String _host = 'localhost';
  final int _port;
  final LocationCanonicalizer _locationCanonicalizer;
  int _exitCode;
  VmService _serviceClient;
  Process _process;
  DateTime _startTime;
  StringBuffer _outputBuffer;
  Future<void> _processExit;
  Duration _timeElapsed;

  /// Construct a [Controller] from a script and a port.
  Controller(this._script, this._port, this._locationCanonicalizer);

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
  Future<Result> run(String input) async {
    _startTime = DateTime.now();
    _outputBuffer = StringBuffer();
    _process.stdin.writeln(jsonEncode(input));
    final fuzz = await _fuzzIsolateComplete();

    final locations = await _getLocations(fuzz);

    await _serviceClient.resume(fuzz.id);
    await _fuzzIsolateDead();

    final jsonOut = await _exponentialBackoff(
        () async => jsonDecode(_outputBuffer.toString().trim()), (_) => true);

    final bool succeeded = jsonOut['success'];
    if (succeeded) {
      return Result(_timeElapsed, locations);
    } else {
      return Result.failed(jsonOut['output'], _timeElapsed, locations);
    }
  }

  Future<VmService> _connect() async {
    final _serviceClient = await _exponentialBackoff(
        () => vmServiceConnect(_host, _port, log: _StdoutLog()),
        (client) => client != null);
    unawaited(_serviceClient.streamListen(EventStreams.kIsolate));
    unawaited(_serviceClient.streamListen(EventStreams.kDebug));
    unawaited(_serviceClient.streamListen(EventStreams.kVM));
    unawaited(_serviceClient.streamListen(EventStreams.kStdout));
    _serviceClient.onDebugEvent.listen((event) {
      if (event.kind == 'PauseExit' && event.isolate.name != 'fuzz_target') {
        _serviceClient.resume(event.isolate.id);
      }
    });
    return _serviceClient;
  }

  Future<T> _exponentialBackoff<T>(
      Future<T> Function() action, bool Function(T) accept,
      {int limit = 50}) async {
    var wait = Duration(milliseconds: 1);

    dynamic reason;

    var i = 0;
    while (i++ < limit) {
      if (_exitCode != null) {
        throw Exception(
            'VM at $_port exited with code $_exitCode:\n$_outputBuffer');
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
      wait += Duration(milliseconds: 1);
    }

    throw Exception('$limit tries exceeded: $reason');
  }

  Future<Isolate> _fuzzIsolateComplete() async {
    _serviceClient.onDebugEvent.listen((event) {
      if (event.kind == 'PauseExit') {
        if (event.isolate.name == 'fuzz_target') {
          _timeElapsed = DateTime.now().difference(_startTime);
        }
      }
    });

    final isolateRef = await _exponentialBackoff(
        () async => (await _serviceClient.getVM())
            .isolates
            .singleWhere((isolate) => isolate.name == 'fuzz_target'),
        (isolate) => isolate != null);

    final isolate = await _exponentialBackoff(
        () async => _serviceClient.getIsolate(isolateRef.id),
        (isolate) => isolate.pauseEvent.kind == 'PauseExit');

    _timeElapsed ??= DateTime.now().difference(_startTime);
    return isolate;
  }

  Future<void> _fuzzIsolateDead() async {
    await _exponentialBackoff(
        () async => (await _serviceClient.getVM()).isolates,
        (isolates) =>
            !isolates.any((isolate) => isolate.name == 'fuzz_target'));
  }

  Future<List<Location>> _getLocations(Isolate isolate) async {
    final scripts = await _serviceClient.getScripts(isolate.id);
    return Future.wait(
      scripts.scripts.map(
        (scriptRef) => _serviceClient.getSourceReport(
            isolate.id, [SourceReportKind.kCoverage],
            scriptId: scriptRef.id),
      ),
    ).then((sourceReports) => sourceReports
        .expand(
          (sourceReport) => sourceReport.ranges.expand(
            (range) =>
                range.coverage?.hits?.map(
                  (id) => _locationCanonicalizer.canonicalize(
                    Location(
                      _locationCanonicalizer
                          .processScriptUri(sourceReport.scripts[0]?.id ?? ""),
                      id,
                    ),
                  ),
                ) ??
                <Location>[],
          ),
        )
        .toList());
  }

  Future<void> _startProcess() async {
    final sdk = path.dirname(path.dirname(Platform.resolvedExecutable));

    _process = await Process.start('$sdk/bin/dart', [
      '--pause_isolates_on_exit',
      '--enable-vm-service=$_port',
      '--disable-service-auth-codes',
      path.join(Platform.environment['HOME'],
          '.pub-cache/global_packages/dust/bin/controller.dart.snapshot.dart2'),
      _script,
    ]);

    final vmCompleter = Completer();
    unawaited(_process.exitCode.then((code) {
      _exitCode = code;
      vmCompleter.complete();
      _serviceClient?.dispose();
      _serviceClient = null;
    }));
    _processExit = vmCompleter.future;

    // ignore: strong_mode_down_cast_composite
    _process.stdout
        .transform(utf8.decoder)
        .listen((output) => _outputBuffer?.write(output));
  }
}

class _StdoutLog extends Log {
  @override
  void severe(String message) => print(message);

  @override
  void warning(String message) => print(message);
}
