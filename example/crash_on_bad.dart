// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

void main(List<String> args) async {
  final input = args[0];

  if (input.length > 0 && input.substring(0, 1) == 'b') {
    if (input.length > 1 && input.substring(1, 2) == 'a') {
      if (input.length > 2 && input.substring(2, 3) == 'd') {
        if (input.length == 3) {
          throw 'bad!';
        }
      }
    }
  }
}
