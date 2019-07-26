// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:math';

/// Returns the last position in [options] that is aligned below [value] that
/// is between [min] and [max].
int _binarySearch<T>(
    List<_AlignedOption<T>> options, double value, int min, int max) {
  while (min < max) {
    final mid = min + ((max - min) >> 1);
    final element = options[mid];
    final comp = element.alignment.compareTo(value);
    if (comp < 0) {
      min = mid + 1; // ignore: parameter_assignments
    } else {
      max = mid; // ignore: parameter_assignments
    }
  }
  return max;
}

/// A list of weighted choices to randomly choose from.
///
/// Usage:
/// ```dart
/// final searchable = WeightedOptions<Person>(people, (person) => person.age);
/// print(searchable.choose(new Random()));
/// ```
///
/// The algorithm is as follows:
/// - For each item, its weight may be calculated by a provided function.
/// - Sort the items by their weight.
/// - We may define the chance of item i being chosen as W_i / sum(W_0...n)
/// - It is thus possible to represent this search. We choose a random double d
///   which is between 0 and sum(W_0-n). We then search for the item such that
///   W_x < sum(W_0...x), but W_x+1 > sum(W_0...x+1).
/// - This is based on a binary search over a sorted list.
/// - However, items at the end of the list are more likely to be chosen than
///   items at the beginning. Therefore, we search for the median likelihood
///   item m, and choose that as our initial 'pivot'.
/// - To keep the search O(log n), we use powers of two when searching after the
///   pivot. Otherwise, the worst case scenario of searching for 0 would be O(n)
///
/// Derivation of performance O(log n). For the item at the pivot, the algorithm
/// completes in one step. For any item above it, we will perform a binary
/// search of O(log a) operations where a is the number of items above the
/// pivot. Since a cannot exceed n, this means total operations cannot exceed
/// log n + 1, and the constant factor is removed. Searching below the pivot
/// follows the same logic.
///
/// TODO(mfairhurst): explore using multiple pivots. This will help much more in
/// a dataset with a skewed distribution, and less in a more normal
/// distribution. Note that an unbounded set of pivots is not O(log n), as each
/// binary search below a pivot is log n + 1 operations. For m pivots, that is
/// log n + m, and if m is unbounded except by n, that would be log n + n, or
/// just O(n). However, an upper bound of, say, m=4 would still be O(log n).
class WeightedOptions<T> {
  final List<T> _options;
  final double Function(T) _getWeight;

  List<_AlignedOption<T>> _alignedOptions;
  int _pivot;

  /// Create weighted options via the options themselves and a callback to get
  /// each options' weight.
  WeightedOptions(this._options, this._getWeight);

  /// Choose an option randomly with probability proportional to its weight.
  T choose(Random random) {
    _presort();
    return _choose(random);
  }

  /// Choose [n] options randomly.
  ///
  /// This is more efficient than calling [choose] [n] times.
  List<T> chooseMany(int n, Random random) {
    _presort();

    return Iterable<T>.generate(n, (t) => _choose(random)).toList();
  }

  T _choose(Random random) {
    final sum = _alignedOptions.last.alignment;
    final choiceAlignment = random.nextDouble() * sum;
    final pivotItem = _alignedOptions[_pivot];

    if (pivotItem.alignment >= choiceAlignment) {
      // item is at or below pivot
      if (_pivot == 0) {
        // the pivot is the head
        return pivotItem.option;
      }

      final pivotItemPrevious = _alignedOptions[_pivot - 1];
      if (pivotItemPrevious.alignment < choiceAlignment) {
        // pivot is the item we want.
        return pivotItem.option;
      } else {
        // pivot is above the item we want.
        return _options[
            _binarySearch(_alignedOptions, choiceAlignment, 0, _pivot - 1)];
      }
    } else {
      // pivot is below the item we want.
      return _options[_binarySearch(_alignedOptions, choiceAlignment,
          _pivot + 1, _alignedOptions.length - 1)];
    }
  }

  void _presort() {
    // sort backwards, least likely first.
    _options.sort((a, b) => _getWeight(a).compareTo(_getWeight(b)));
    final weightSum = _options.fold(0.0, (acc, item) => acc + _getWeight(item));

    _alignedOptions = List<_AlignedOption<T>>(_options.length);
    _pivot = null;

    var i = 0;
    var currentSum = 0.0;
    for (final option in _options) {
      currentSum += _getWeight(option);
      _alignedOptions[i] = _AlignedOption(option, currentSum);

      if (_pivot == null && currentSum > weightSum / 2) {
        _pivot = i;
      }

      i++;
    }
  }
}

/// Represents option i in a [WeightedOptions] list, along with sum(W_0...i).
class _AlignedOption<T> {
  final T option;
  final double alignment;
  _AlignedOption(this.option, this.alignment);
}
