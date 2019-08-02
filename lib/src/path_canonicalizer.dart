// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dust/src/path.dart';

/// Utility to reduce memory by canonicalizing/normalizing [Path]s.
class PathCanonicalizer {
  final bool _compress;
  final _paths = <Path>{};
  final _scripts = <String>{};

  /// Create a canonicalizer which optionally compresses URIs as well.
  PathCanonicalizer({bool compress = false}) : _compress = compress;

  /// Add this Path to the canonical pool and/or return the canonical
  /// version.
  Path canonicalize(Path path) {
    final preexisting = _paths.lookup(path);
    if (preexisting != null) {
      return preexisting;
    }
    _paths.add(path);
    return path;
  }

  /// Clean up a VM script URI into a lower memory, compressed or human readable
  /// one.
  String processScriptUri(String scriptUri) => _canonicalizeScriptName(
      _compress ? _compressScriptUri(scriptUri) : _cleanScriptUri(scriptUri));

  /// Add this script URI to the canonical pool and/or return the canonical
  /// version.
  ///
  /// Many paths will share potentially tens of thousands of [Path]s
  /// that differ only in script URI.
  String _canonicalizeScriptName(String scriptUri) {
    final preexisting = _scripts.lookup(scriptUri);
    if (preexisting != null) {
      return preexisting;
    }
    _scripts.add(scriptUri);
    return scriptUri;
  }

  /// Clean up a VM script URI into a lower memory, human readable one.
  String _cleanScriptUri(String scriptUri) => scriptUri
      .split('/')[3]
      .replaceAll('%2F', '/')
      .replaceAll('file%3A//', '');

  /// Clean up a VM script URI into compressed lower memory hash.
  ///
  /// TODO(mfairhurst): investigate lossless compression.
  String _compressScriptUri(String scriptUri) =>
      md5.convert(scriptUri.codeUnits).toString();
}
