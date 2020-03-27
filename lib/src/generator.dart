import 'dart:async';

import 'package:build/build.dart';
import 'package:glob/glob.dart';
import 'package:source_gen/source_gen.dart';
import 'package:umbrella_annotation/umbrella_annotation.dart';
import 'package:umbrella_generator/src/exporter/code_exporter.dart';
import 'package:umbrella_generator/src/reader/header_annotation_reader.dart';

const _moduleAnnotationChecker = TypeChecker.fromRuntime(Header);

class HeaderGenerator extends Generator {

  @override
  FutureOr<String> generate(LibraryReader library, BuildStep buildStep) async {

    final annotationsOnLibrary = _moduleAnnotationChecker.annotationsOf(library.element);
    print("Found ${annotationsOnLibrary.length} annotations on ${library.element.librarySource.uri}");

    if (annotationsOnLibrary.isEmpty) {
      // Silently ignore
      return null;
    }

    if (annotationsOnLibrary.length > 1) {
      // Warn and exit
      print("Found more than 1 @Header annotation on ${library.element.source.uri}, @Header annotation must be unique.\n"
          "Consider adding another file for the second header if needed.");
      return null;
    }

    // Read the annotation values
    final headerAnnotation = HeaderAnnotationReader.read(ConstantReader(annotationsOnLibrary.first));

    // Find all exportable items
    final exportableItems = await _scanExportableItems(buildStep, headerAnnotation);

    // Generate header file contents from file paths, ignore the path of the header file itself
    return exportableItems
        .where((element) => element != library.element.source.uri)
        .map((uri) => CodeExporter.packageExportDirective(uri.toString()))
        .join("\n") + "\n";
  }
}

Future<List<Uri>> _scanExportableItems(BuildStep buildStep, Header headerAnnotation) async {

  // Fetch all assets
  var allAssets = await buildStep.findAssets(Glob(headerAnnotation.glob ?? "**"))
      .where((assetId) => assetId.uri.scheme == "package")
      .toList();

  // Filter out files which are not dart libraries
  var librariesToExport = <Uri>[];
  for (var assetId in allAssets) {
    if (!await buildStep.resolver.isLibrary(assetId)) {
      continue;
    }

    final fileUri = assetId.uri;
    final fileName = fileUri.pathSegments.last;

    if (fileName == null || fileName.isEmpty) {
      throw StateError("Invalid asset uri: ${fileUri}");
    }

    if (headerAnnotation.ignorePrivateFiles && fileName.startsWith("_")) {
      continue;
    }

    if (headerAnnotation.ignoreGeneratedFiles && fileName.endsWith(".g.dart")) {
      continue;
    }

    librariesToExport.add(fileUri);
  }

  return librariesToExport;
}