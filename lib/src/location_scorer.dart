// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:math';
import 'dart:async';

import 'package:dust/src/location.dart';

/// Determines the uniqueness of a [Location] against all previously seen
/// [Location]s and a configurable "sensitivity."
///
/// When a [Location] is seen it must be reported via [report]. Note, this is
/// NOT an idempotent operation. Take care each [Location] is reported exactly
/// once.
///
/// The score of a [Location] is 1/n^s where n is the number of fuzz cases that
/// have executed that location, and s is the sensitivity.
///
/// A higher sensitivity will value a few rare [Location]s over a large number
/// of common [Location]s. There is a balance to be struck here. A good default
/// value to experiment from is 2.
///
/// Also note that the score of a [Location] will change over time. In the case
/// of a fuzz tester, a new path may be interesting at first, but become less
/// interesting as it fuzzes based on that seed, and the new interesting paths
/// get repetivitely explored.
///
/// TODO: score unique files as well as unique paths?
class LocationScorer {
  final _locationOccurences = <Location, int>{};

  final _newLocationCtrl = StreamController<void>.broadcast();

  /// Get a stream of events for when new paths are discovered.
  Stream<void> get onNewLocation => _newLocationCtrl.stream;

  final double _sensitivity;

  /// Create a new [LocationScorer] with the given sensitivity.
  LocationScorer(this._sensitivity);

  // TODO: add a bloom filter to make this faster?
  /// Check if a [Location] has been seen previously by this scorer.
  bool isNew(Location location) => !_locationOccurences.containsKey(location);

  /// Report a [Location] for scoring later.
  void report(Location location) => _locationOccurences
    ..update(location, (value) => ++value, ifAbsent: () {
      _newLocationCtrl.add(null);
      return 1;
    });

  /// Score a [Location] (higher is more unique).
  double score(Location location) =>
      pow(1.0 / (_locationOccurences[location] ?? 1), _sensitivity);

  /// Score a set of [Location]s (higher is more unique).
  double scoreAll(List<Location> locations) =>
      locations.map(score).reduce((a, b) => a + b);
}
