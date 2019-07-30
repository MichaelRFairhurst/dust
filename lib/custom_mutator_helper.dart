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
void customMutatorHelper(SendPort sendPort, String Function(String) mutator) {
  final port = ReceivePort()
    ..listen((msg) {
      final int id = msg[0];
      final String string = msg[1];

      final output = mutator(string);

      sendPort.send([id, output]);
    });

  sendPort.send(port.sendPort);
}
