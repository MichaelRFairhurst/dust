// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:quiver/core.dart' as q;

class Location {
  final String scriptUri;
  final int locationId;

  Location(this.scriptUri, this.locationId);

  int get hashCode => q.hash2(scriptUri.hashCode, locationId.hashCode);

  bool operator ==(Object other) =>
      other is Location &&
      other.scriptUri == scriptUri &&
      other.locationId == locationId;

  String toString() => '$scriptUri:$locationId';
}
