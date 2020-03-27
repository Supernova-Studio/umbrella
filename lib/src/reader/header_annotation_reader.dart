import 'package:source_gen/source_gen.dart';
import 'package:umbrella_annotation/umbrella_annotation.dart';
import 'package:umbrella_generator/src/utils/constant_reader_ext.dart';

class HeaderAnnotationReader {
  static Header read(ConstantReader reader) {
    return Header(
      glob: reader.readTypedOptional("glob", asString),
      ignoreGeneratedFiles: reader.readTyped("ignoreGeneratedFiles", asBool),
      ignorePrivateFiles: reader.readTyped("ignorePrivateFiles", asBool),
    );
  }
}
