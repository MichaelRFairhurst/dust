import 'dart:async';
import 'dart:isolate';

/// A wrapper for a function to help write isolate mutators.
///
/// With this function, you can implement a mutator script like so:
///
/// ```dart
/// import 'dart:isolate';
/// import 'package:dust/custom_mutator_helper.dart';
///
/// main(args, SendPort sendPort) => customMutatorHelper(sendPort, (str) {
///   return ...; // mutate the string
/// });
/// ```
///
/// And then use it with `pub run dust --mutator_script=script.dart ...`.
void customMutatorHelper(
    SendPort sendPort, FutureOr<String> Function(String) mutator) {
  final port = ReceivePort()
    ..listen((msg) async {
      final int id = msg[0];
      final String string = msg[1];

      String response;
      while (response == null) {
        try {
          final output = mutator(string);
          if (output is Future<String>) {
            response = await output;
          } else {
            response = output;
          }
        } catch (e, st) {
          print('$e\n$st');
        }
      }
      sendPort.send([id, response]);
    });

  sendPort.send(port.sendPort);
}
