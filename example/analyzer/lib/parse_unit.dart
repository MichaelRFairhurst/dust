// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

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

Future<ParsedUnitResult> parseUnit(String input) async {
  final ByteStore byteStore = MemoryByteStore();

  final logBuffer = StringBuffer();
  PerformanceLog logger;

  DartSdk sdk;
  Map<String, List<Folder>> packageMap;
  AnalysisDriver driver;
  AnalysisDriverScheduler scheduler;

  final analysisOptions = AnalysisOptionsImpl();

  final resourceProvider = MemoryResourceProvider();

  String convertPath(String path) => resourceProvider.convertPath(path);

  Folder getFolder(String path) {
    final convertedPath = convertPath(path);
    return resourceProvider.getFolder(convertedPath);
  }

  sdk = MockSdk(resourceProvider: resourceProvider);
  logger = PerformanceLog(logBuffer);
  scheduler = AnalysisDriverScheduler(logger);

  packageMap = <String, List<Folder>>{
    'test': [getFolder('/test/lib')],
    'meta': [getFolder('/.pub-cache/meta/lib')],
  };

  driver = AnalysisDriver(
      scheduler,
      logger,
      resourceProvider,
      byteStore,
      FileContentOverlay(),
      null,
      SourceFactory([
        DartUriResolver(sdk),
        PackageMapUriResolver(resourceProvider, packageMap),
        ResourceUriResolver(resourceProvider)
      ], null, resourceProvider),
      analysisOptions);

  scheduler.start();

  File newFile(String path, {String content = ''}) {
    final convertedPath = convertPath(path);
    return resourceProvider.newFile(convertedPath, content);
  }

  void addTestFile(String content) {
    newFile('/test/lib/test.dart', content: content);
  }

  addTestFile(input);
  return driver.parseFile('/test/lib/test.dart');
}
