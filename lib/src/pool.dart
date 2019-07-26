// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';

/// A pool of workers that can asynchronously consume a queue.
class Pool<W, D> {
  final List<W> _workers;

  /// The function of how to consume a queue item given a single worker.
  final Future<void> Function(W, D) _use;

  /// Error handler which accepts the worker that failed, the item it failed on,
  /// and the error that was raised.
  final Future<bool> Function(W, D, Object) _handleError;

  /// Create a [Pool] of workers, along with how they run and an optional error
  /// handler.
  Pool(this._workers, this._use,
      {Future<bool> Function(W, D, Object) handleError})
      : _handleError = handleError;

  /// Give the pool a [Queue] to work through before the resulting future
  /// completes.
  Future<void> consume(Queue<D> queue) async {
    await Future.wait(_workers.map((worker) => _singleWorker(worker, queue)));
  }

  Future<void> _singleWorker(W worker, Queue<D> queue) async {
    while (queue.isNotEmpty) {
      final item = queue.removeLast();
      try {
        await _use(worker, item);
      } catch (e) {
        if (await _handleError(worker, item, e)) {
          queue.add(item);
        }
      }
    }
  }
}
