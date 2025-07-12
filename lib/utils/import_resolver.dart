import 'package:analyzer/dart/ast/ast.dart';

class ImportResolver {
  // Parses Dart import directives and returns a map of prefix -> import path
  static Map<String, String> parseImportsFromUnit(CompilationUnit unit) {
    final imports = <String, String>{};
    for (final directive in unit.directives) {
      if (directive is ImportDirective && directive.prefix != null) {
        imports[directive.prefix!.name] = directive.uri.stringValue ?? '';
      }
    }
    return imports;
  }

  // Finds all _iX.TypeName usages in a Dart code string
  static Set<String> findPrefixedTypeReferences(String code) {
    final regex = RegExp(r'_i\d+\.([A-Za-z0-9_]+)');
    return regex.allMatches(code).map((m) => m.group(1)!).toSet();
  }

  // Generates a TypeScript import line for a type from a file
  static String generateTsImport(String typeName, String fromFile) {
    return "import { $typeName } from '$fromFile';";
  }

  // Maps a Dart import path and type name to a TS import path (relative, no extension)
  static String mapDartImportToTsPath(String dartImportPath, String typeName) {
    return './models/${_toSnake(typeName)}';
  }

  static String _toSnake(String s) {
    return s
        .replaceAllMapped(
          RegExp(r'([a-z0-9])([A-Z])'),
          (m) => '${m[1]}_${m[2]}',
        )
        .toLowerCase();
  }

  // TODO: Map Dart import path to TS file path

  // Extracts a map of type name to prefix from Dart code (e.g., {MyModel: _i1})
  static Map<String, String> extractTypePrefixMap(String code) {
    final regex = RegExp(r'(_i\d+)\.([A-Za-z0-9_]+)');
    final map = <String, String>{};
    for (final match in regex.allMatches(code)) {
      final prefix = match.group(1)!;
      final type = match.group(2)!;
      map[type] = prefix;
    }
    return map;
  }
}
