import 'package:serverpod_ts_gen/utils/type_converter.dart';

extension StringExtension on String {
  String get camelCase {
    if (isEmpty) return this;
    return this[0].toLowerCase() + substring(1);
  }

  String get snakeCase {
    return replaceAllMapped(
      RegExp(r'([a-z0-9])([A-Z])'),
      (m) => '${m[1]}_${m[2]}',
    ).toLowerCase();
  }

  TsTypeData get toTsType => TypeConverter.toTsType(this);
}
