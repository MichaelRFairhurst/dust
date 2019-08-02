// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:meta/meta.dart';

/// A seed that was input to the program and has not yet been verified.
class SeedCandidate {
  /// The fuzz string to pass into the script.
  final String input;

  /// The filename where this candidate came from, if one exists.
  final String filename;

  /// Whether this seed was found in the corpus vs other type of input.
  final bool inCorpus;

  /// Whether this seed candidate was accepted.
  bool accepted;

  /// Create a candidate that came from a file, potentially [inCorpus].
  SeedCandidate.forFile(this.input, this.filename, {@required this.inCorpus});

  /// Create a candidate that a user entered on the command line.
  SeedCandidate.forText(this.input)
      : filename = null,
        inCorpus = false;

  /// Create an initial candidate if corpus is empty and no candidates provided.
  SeedCandidate.initial()
      : input = '',
        filename = 'initial empty string',
        inCorpus = true;

  /// Get a string to identify this seed to the user; either its filename or its
  /// input.
  String get userString => filename ?? input;
}
