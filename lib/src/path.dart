// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:quiver/core.dart' as q;

/// Represents a code path that was or wasn't executed by the VM.
///
/// The VM provides both a special canonicalized URI string, and also a unique
/// integer identifier based on the code offset of the code path. This class
/// should be constructed with the integer ID unchanged, but the script URI
/// made shorter & more human readable.
class Path {
  /// The script URI of the executed code path.
  final String scriptUri;

  /// The VM location ID (within a script) for this code path.
  final int locationId;

  /// Construct a [Path] with the given script & VM location ID.
  Path(this.scriptUri, this.locationId);

  @override
  int get hashCode => q.hash2(scriptUri.hashCode, locationId.hashCode);

  @override
  bool operator ==(Object other) =>
      other is Path &&
      other.scriptUri == scriptUri &&
      other.locationId == locationId;

  @override
  String toString() => '$scriptUri:$locationId';
}
