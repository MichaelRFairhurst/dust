// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dust/src/location.dart';

/// Utility to reduce memory by canonicalizing/normalizing [Location]s.
class LocationCanonicalizer {
  final bool _compress;
  final _locations = <Location>{};
  final _paths = <String>{};

  /// Create a canonicalizer which optionally compresses URIs as well.
  LocationCanonicalizer({bool compress = false}) : _compress = compress;

  /// Add this Location to the canonical pool and/or return the canonical
  /// version.
  Location canonicalize(Location location) {
    final preexisting = _locations.lookup(location);
    if (preexisting != null) {
      return preexisting;
    }
    _locations.add(location);
    return location;
  }

  /// Clean up a VM script URI into a lower memory, compressed or human readable
  /// one.
  String processScriptUri(String scriptUri) => _canonicalizeScriptName(
      _compress ? _compressScriptUri(scriptUri) : _cleanScriptUri(scriptUri));

  /// Add this script URI to the canonical pool and/or return the canonical
  /// version.
  ///
  /// Many locations will share potentially tens of thousands of [Location]s
  /// that differ only in script URI.
  String _canonicalizeScriptName(String scriptUri) {
    final preexisting = _paths.lookup(scriptUri);
    if (preexisting != null) {
      return preexisting;
    }
    _paths.add(scriptUri);
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
