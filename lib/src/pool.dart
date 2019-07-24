// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';

class Pool<W, D> {
  final List<W> workers;
  final Future<void> Function(W, D) use;

  Pool(this.workers, this.use);

  Future<void> consume(Queue<D> queue) async {
    await Future.wait(workers.map((worker) => _singleWorker(worker, queue)));
  }

  Future<void> _singleWorker(W worker, Queue<D> queue) async {
    while (queue.isNotEmpty) {
      await use(worker, queue.removeLast());
    }
  }
}
