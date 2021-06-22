import 'dart:async';

import 'package:build/build.dart';
import 'package:glob/glob.dart';
import 'package:source_gen/source_gen.dart';
import 'package:umbrella_annotation/umbrella_annotation.dart';
import 'package:umbrella_generator/src/errors/analysis_error.dart';
import 'package:umbrella_generator/src/exporter/code_exporter.dart';
import 'package:umbrella_generator/src/reader/header_annotation_reader.dart';
import 'package:umbrella_generator/src/utils/log_storage.dart';

const _moduleAnnotationChecker = TypeChecker.fromRuntime(Header);

class HeaderGenerator extends Generator {
  @override
  FutureOr<String> generate(LibraryReader library, BuildStep buildStep) async {
    try {
      final result = await _processLibrary(library, buildStep);
      return result;
    } catch (e, stackTrace) {
      print("Catched error while processing ${library.element.source.uri}\n"
          "Please submit this report to https://github.com/Supernova-Studio/umbrella/issues\n"
          "$e\n"
          "$stackTrace");
      rethrow;
    }
  }
}

Future<String> _processLibrary(LibraryReader library, BuildStep buildStep) async {
  final logStorage = LogStorage();
  String output = "";

  final annotationsOnLibrary = _moduleAnnotationChecker.annotationsOf(library.element);
  logStorage.add(LogLevel.debug, "Found ${annotationsOnLibrary.length} annotations on ${library.element.librarySource.uri}");

  if (annotationsOnLibrary.isEmpty) {
    // Dump debug message
    logStorage.add(LogLevel.debug, "${library.element.source.uri} does not contain @Header() annotation, skip");
  } else if (annotationsOnLibrary.length > 1) {
    // Dump error
    logStorage.add(
      LogLevel.error,
      "Found more than 1 @Header annotation on ${library.element.source.uri}, @Header annotation must be unique.\n"
      "Consider adding another file for the second header if needed.",
    );
  } else {
    logStorage.add(LogLevel.debug, "${library.element.source.uri}: found @Header annotation");

    // Read the annotation values
    final headerAnnotation = HeaderAnnotationReader.read(ConstantReader(annotationsOnLibrary.first));
    logStorage.add(LogLevel.debug, "Read annotation values: ${headerAnnotation.toString()}");

    // Find all exportable items, ignore the path of the header file itself
    final exportableItems = (await _scanExportableItems(buildStep, headerAnnotation, logStorage))
        .where((element) => element != library.element.source.uri)
        .toList();

    exportableItems.sort((a, b) => a.toString().compareTo(b.toString()));

    if (exportableItems.isEmpty) {
      print("Couldn't find any exportable libraries for Header in ${library.element.source.uri}\n"
          "---------- Dumping debug info ----------");
      print(logStorage.assembleMessage(LogLevel.debug));
      logStorage.clear();
      print("---------- End of debug info ----------");
    }

    // Generate header file contents from file paths
    output = exportableItems.map((uri) => CodeExporter.packageExportDirective(uri.toString())).join("\n") + "\n";
  }

  // Dump logs if needed
  final logMessage = logStorage.assembleMessage(LogLevel.warning);
  if (logMessage.isNotEmpty) {
    print(logMessage);
  }

  return output;
}

Future<List<Uri>> _scanExportableItems(BuildStep buildStep, Header headerAnnotation, LogStorage logStorage) async {
  Glob include;
  Glob? exclude;

  if (headerAnnotation.include.isEmpty) {
    logStorage.add(
        LogLevel.warning,
        "Found empty `include` glob list within @Header annotation, "
        "consider adding at least one glob expression");
    return const [];
  } else if (headerAnnotation.include.length == 1) {
    include = Glob(headerAnnotation.include.first);
  } else {
    include = Glob("{${headerAnnotation.include.join(',')}}");
  }

  if (headerAnnotation.exclude.isEmpty) {
    exclude = null;
  } else if (headerAnnotation.exclude.length == 1) {
    exclude = Glob(headerAnnotation.exclude.first);
  } else {
    exclude = Glob("{${headerAnnotation.exclude.join(',')}}");
  }

  // Fetch all assets
  var allAssets = await buildStep.findAssets(include).where((assetId) => assetId.uri.scheme == "package").toList();

  logStorage.add(LogLevel.debug, "Found ${allAssets.length} potentially exportable entries");

  // Filter out files which are not dart libraries
  var librariesToExport = <Uri>[];
  for (var assetId in allAssets) {
    if (exclude != null && exclude.matches(assetId.path)) {
      logStorage.add(LogLevel.debug, "Skipping ${assetId.uri.toString()}: excluded by `exclude` glob");
      continue;
    }

    try {
      final uri = await _analyzeAsset(assetId, headerAnnotation, buildStep, logStorage);
      if (uri != null) {
        librariesToExport.add(uri);
      }
    } catch (e) {
      throw AnalysisError("Error analyzing ${assetId.uri.toString()}", causedBy: e);
    }
  }

  return librariesToExport;
}

Future<Uri?> _analyzeAsset(AssetId assetId, Header headerAnnotation, BuildStep buildStep, LogStorage logStorage) async {
  // Extract Uri from the asset id
  final fileUri = assetId.uri;
  final fileName = fileUri.pathSegments.last;
  if (fileName == null || fileName.isEmpty) {
    throw StateError("Invalid asset uri: ${fileUri}");
  }

  // Check if it's a dart source code
  if (!fileName.endsWith(".dart")) {
    logStorage.add(LogLevel.debug, "Skipping ${assetId.uri.toString()}: not a dart library");
    return null;
  }

  // Check if it's a private file and if we should ignore it
  if (headerAnnotation.ignorePrivateFiles && fileName.startsWith("_")) {
    logStorage.add(LogLevel.debug, "Skipping ${assetId.uri.toString()}: ignoring a private file");
    return null;
  }

  // Check if it's a generated file and we should ignore it
  if (headerAnnotation.ignoreGeneratedFiles && fileName.endsWith(".g.dart")) {
    logStorage.add(LogLevel.debug, "Skipping ${assetId.uri.toString()}: ignoring a generated file");
    return null;
  }

  return fileUri;
}
