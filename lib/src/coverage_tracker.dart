import 'package:dust/src/path.dart';

/// Tracking for which coverage exists, and which coverage has been triggered.
///
/// This is used to generate coverage stats and reports.
class CoverageTracker {
  final _pathOccurrences = <Path, int>{};
  final _allPaths = <Path>{};
  final _compiledFiles = <String>{};
  final _allFiles = <String>{};

  /// Total files the VM has reported exist.
  int get totalFiles => _allFiles.length;

  /// Total paths the VM has reported exist.
  int get totalPaths => _allPaths.length;

  /// Files the VM has at least partially compiled.
  int get visitedFiles => _compiledFiles.length;

  /// Paths the VM has compiled.
  int get visitedPaths => _pathOccurrences.keys.length;

  /// Whether a Path has been executed or not.
  bool hasOccurred(Path path) => _pathOccurrences.containsKey(path);

  /// How many fuzz cases have executed the [path].
  int occurrenceCount(Path path) => _pathOccurrences[path] ?? 0;

  /// Report that a file exists with coverage info.
  void reportFileHasCoverage(String uri) {
    _compiledFiles.add(uri);
    _allFiles.add(uri);
  }

  /// Report that a file exists but did not have any coverage info.
  void reportFileHasNoCoverage(String uri) => _allFiles.add(uri);

  /// Report that coverage indicated that this path was not triggered.
  void reportPathMissed(Path path) => _allPaths.add(path);

  /// Report that a fuzz case (or seed) triggered this [path].
  void reportPathOccurred(Path path) {
    _pathOccurrences.update(path, (value) => ++value, ifAbsent: () => 1);
    _allPaths.add(path);
  }
}
