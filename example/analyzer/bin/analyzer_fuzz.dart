import 'dart:async';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/file_system/file_system.dart';
import 'package:analyzer/file_system/memory_file_system.dart';
import 'package:analyzer/src/dart/analysis/byte_store.dart';
import 'package:analyzer/src/dart/analysis/driver.dart';
import 'package:analyzer/src/dart/analysis/file_state.dart';
import 'package:analyzer/src/dart/analysis/performance_logger.dart';
import 'package:analyzer/src/generated/engine.dart' show AnalysisOptionsImpl;
import 'package:analyzer/src/generated/sdk.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/source/package_map_resolver.dart';
import 'package:analyzer/src/test_utilities/mock_sdk.dart';
import 'package:analyzer/src/test_utilities/resource_provider_mixin.dart';

void main(List<String> args) async {
  final input = args[0];

  final ByteStore byteStore = new MemoryByteStore();

  final StringBuffer logBuffer = new StringBuffer();
  PerformanceLog logger;

  DartSdk sdk;
  Map<String, List<Folder>> packageMap;
  AnalysisDriverScheduler scheduler;
  AnalysisDriver driver;

  AnalysisOptionsImpl analysisOptions = AnalysisOptionsImpl();

  final resourceProvider = MemoryResourceProvider();

  String convertPath(String path) => resourceProvider.convertPath(path);

  Folder getFolder(String path) {
    String convertedPath = convertPath(path);
    return resourceProvider.getFolder(convertedPath);
  }

  sdk = new MockSdk(resourceProvider: resourceProvider);
  logger = new PerformanceLog(logBuffer);
  scheduler = new AnalysisDriverScheduler(logger);

  packageMap = <String, List<Folder>>{
    'test': [getFolder('/test/lib')],
    'meta': [getFolder('/.pub-cache/meta/lib')],
  };

  driver = new AnalysisDriver(
      scheduler,
      logger,
      resourceProvider,
      byteStore,
      new FileContentOverlay(),
      null,
      new SourceFactory([
        new DartUriResolver(sdk),
        new PackageMapUriResolver(resourceProvider, packageMap),
        new ResourceUriResolver(resourceProvider)
      ], null, resourceProvider),
      analysisOptions);

  scheduler.start();

  File newFile(String path, {String content = ''}) {
    String convertedPath = convertPath(path);
    return resourceProvider.newFile(convertedPath, content);
  }

  void addTestFile(String content) {
    newFile('/test/lib/test.dart', content: content);
  }

  Future<ResolvedUnitResult> resolveFile(String path) async {
    return await driver.getResult(path);
  }

  Future<void> resolveTestFile() async {
    var path = convertPath('/test/lib/test.dart');
    await resolveFile(path);
  }

  addTestFile(input);
  await resolveTestFile();
}
