import 'dart:async';
import 'dart:isolate';
import 'dart:math';

import 'package:dust/src/mutator.dart';
import 'package:path/path.dart' as path;

/// An isolate that exposes a [Mutator] function.
///
/// Don't forget to [dispose] of this when done with it, or the ports involved
/// will keep your executable open.
class IsolateMutator implements WeightedMutator {
  final String _scriptPath;
  @override
  final double weight;
  Isolate _isolate;
  ReceivePort _receivePort;
  ReceivePort _onErrorPort;
  ReceivePort _onExitPort;
  SendPort _sendPort;

  @override
  Mutator mutatorFn;

  int _ids = 0;
  final _completers = <int, Completer<String>>{};

  /// Construct an [IsolateMutator] with the given script and weight.
  IsolateMutator(this._scriptPath, this.weight);

  /// Dispose of this isolate.
  void dispose() {
    _isolate.kill();
    _isolate = null;
    _sendPort = null;
    _receivePort.close();
    _onErrorPort.close();
    _onExitPort.close();
  }

  /// Start this IsolateMutator at the given [scriptPath].
  Future<void> start() async {
    _receivePort = ReceivePort()
      ..listen((msg) {
        if (_sendPort == null) {
          _sendPort = msg;
          return;
        }
        final int id = msg[0];
        final String resp = msg[1];

        _completers[id].complete(resp);
        _completers.remove(id);
      });

    _onErrorPort = ReceivePort()
      ..listen((msg) {
        dispose();
        _completers.forEach((_, c) => c.completeError(msg));
        start();
      });

    _onExitPort = ReceivePort()
      ..listen((msg) {
        dispose();
        _completers.forEach((_, c) => c.completeError('isolate closed'));
        start();
      });

    _isolate = await Isolate.spawnUri(
        Uri.file(path.join(path.current, _scriptPath)),
        [],
        _receivePort.sendPort,
        onError: _onErrorPort.sendPort,
        onExit: _onExitPort.sendPort);

    mutatorFn = (String input, Random _) async {
      final id = _ids++;
      _sendPort.send([id, input]);
      _completers[id] = Completer<String>();
      return _completers[id].future;
    };
  }
}
