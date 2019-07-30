// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:front_end/src/fasta/parser/listener.dart' show Listener;
import 'package:front_end/src/fasta/parser/top_level_parser.dart'
    show TopLevelParser;
import 'package:front_end/src/fasta/scanner.dart' show scan;

Future<void> main(List<String> arguments) async {
  final input = arguments[0];
  TopLevelParser(DebugListener())
      .parseUnit(scan(List.from(input.codeUnits)..add(0)).tokens);
}

class DebugListener extends Listener {
  @override
  void handleIdentifier(Object token, Object context) {}

  @override
  void logEvent(String name) {}
}
