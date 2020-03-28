import 'dart:async';

import 'package:build/build.dart';
import 'package:glob/glob.dart';
import 'package:source_gen/source_gen.dart';
import 'package:umbrella_annotation/umbrella_annotation.dart';
import 'package:umbrella_generator/src/exporter/code_exporter.dart';
import 'package:umbrella_generator/src/reader/header_annotation_reader.dart';
import 'package:umbrella_generator/src/utils/log_storage.dart';

const _moduleAnnotationChecker = TypeChecker.fromRuntime(Header);

class HeaderGenerator extends Generator {
  @override
  FutureOr<String> generate(LibraryReader library, BuildStep buildStep) async {
    final logStorage = LogStorage();
    String output;

    final annotationsOnLibrary = _moduleAnnotationChecker.annotationsOf(library.element);
    logStorage.add(
        LogLevel.debug, "Found ${annotationsOnLibrary.length} annotations on ${library.element.librarySource.uri}");

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
          .where((element) => element != library.element.source.uri);

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
}

Future<List<Uri>> _scanExportableItems(BuildStep buildStep, Header headerAnnotation, LogStorage logStorage) async {
  // Fetch all assets
  var allAssets = await buildStep
      .findAssets(Glob(headerAnnotation.glob ?? "**"))
      .where((assetId) => assetId.uri.scheme == "package")
      .toList();

  logStorage.add(LogLevel.debug, "Found ${allAssets.length} potentially exportable entries");

  // Filter out files which are not dart libraries
  var librariesToExport = <Uri>[];
  for (var assetId in allAssets) {
    if (!await buildStep.resolver.isLibrary(assetId)) {
      logStorage.add(LogLevel.debug, "Skipping ${assetId.uri.toString()}: not a dart library");
      continue;
    }

    final fileUri = assetId.uri;
    final fileName = fileUri.pathSegments.last;

    if (fileName == null || fileName.isEmpty) {
      throw StateError("Invalid asset uri: ${fileUri}");
    }

    if (headerAnnotation.ignorePrivateFiles && fileName.startsWith("_")) {
      logStorage.add(LogLevel.debug, "Skipping ${assetId.uri.toString()}: ignoring a private file");
      continue;
    }

    if (headerAnnotation.ignoreGeneratedFiles && fileName.endsWith(".g.dart")) {
      logStorage.add(LogLevel.debug, "Skipping ${assetId.uri.toString()}: ignoring a generated file");
      continue;
    }

    librariesToExport.add(fileUri);
  }

  return librariesToExport;
}
