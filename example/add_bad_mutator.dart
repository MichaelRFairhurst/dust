import 'dart:isolate';

import 'package:dust/custom_mutator_helper.dart';

main(args, SendPort sendPort) => customMutatorHelper(sendPort, (str) => 'bad');
