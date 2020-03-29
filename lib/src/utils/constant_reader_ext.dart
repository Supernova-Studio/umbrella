import 'package:source_gen/source_gen.dart';

typedef ValueConverter<T> = T Function(ConstantReader reader);
extension ConstantReaderExtension on ConstantReader {

  String readOptionalString(String field) {
    return readTyped(field, asString);
  }

  T readTypedOptional<T>(String field, ValueConverter<T> converter) {
    final value = this.read(field);
    return value.isNull ? null : converter(value);
  }

  T readTyped<T>(String field, ValueConverter<T> converter) => converter(this.read(field));

  List<T> readTypedList<T>(String field, ValueConverter<T> converter) {
    return this.read(field).listValue.map((e) => converter(ConstantReader(e))).toList();
  }
}

String asString(ConstantReader reader) => reader.stringValue;
bool asBool(ConstantReader reader) => reader.boolValue;