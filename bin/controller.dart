// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:pedantic/pedantic.dart';

Future main(List<String> args) async {
  final isolateScript = args[0];
  final timeout = args.length > 1 ? int.parse(args[1]) : 10;
  var pretext = '';

  stdin.listen((input) async {
    var succeeded = true;
    final output = StringBuffer();
    try {
      String value;
      try {
        value = jsonDecode(pretext + String.fromCharCodes(input));
        pretext = '';
      } catch (e) {
        pretext = pretext + String.fromCharCodes(input);
        return;
      }

      final onError = RawReceivePort();
      final onComplete = RawReceivePort();
      final isolateDone = Completer();

      onError.handler = (error) {
        output.write(error);
        succeeded = false;
      };
      onComplete.handler = (_) {
        onError.close();
        onComplete.close();
        isolateDone.complete();
      };

      final isolateUri = Uri.base.resolve(isolateScript);
      final isolate = await Isolate.spawnUri(isolateUri, [value], null,
          onError: onError.sendPort,
          onExit: onComplete.sendPort,
          debugName: 'fuzz_target');

      unawaited(Future.delayed(Duration(seconds: timeout)).then((_) {
        if (!isolateDone.isCompleted) {
          isolate.kill(priority: Isolate.immediate);
          succeeded = false;
          output.write('timed out in ${timeout}s');
        }
      }));
      await isolateDone.future;
    } catch (e) {
      print(jsonEncode({'success': false, 'output': e.toString()}));
      return;
    }

    print(jsonEncode({'success': succeeded, 'output': output.toString()}));
  });
}
