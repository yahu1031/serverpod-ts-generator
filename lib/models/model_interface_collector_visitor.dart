import 'package:analyzer/dart/ast/ast.dart';

import '../utils/import_resolver.dart';
import '../utils/type_utils.dart';
import 'model_interface.dart';

String? extractModelDocComment(AnnotatedNode node) {
  final doc = node.documentationComment;
  if (doc == null) return null;
  return doc.tokens.map((t) => t.toString().replaceFirst('///', '').trim()).join('\n');
}

class ModelInterfaceCollectorVisitor implements AstVisitor<void> {
  final List<ModelInterface> models = [];
  Map<String, String> importPrefixes = {};
  Set<String> referencedTypes = {};
  Map<String, String> typePrefixMap = {};

  @override
  void visitCompilationUnit(CompilationUnit node) {
    importPrefixes = ImportResolver.parseImportsFromUnit(node);
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    // Only generate interface if class has fields
    final fields = node.members.whereType<FieldDeclaration>().toList();
    if (fields.isEmpty) return;
    final buffer = StringBuffer();
    final classDoc = extractModelDocComment(node);
    if (classDoc != null && classDoc.isNotEmpty) {
      buffer.writeln('/**');
      for (final line in classDoc.split('\n')) {
        buffer.writeln(' * $line');
      }
      buffer.writeln(' */');
    }
    buffer.writeln('export interface ${node.name.lexeme} {');
    for (final field in fields) {
      final fieldDoc = extractModelDocComment(field);
      for (final v in field.fields.variables) {
        final type = field.fields.type?.toSource() ?? 'any';
        referencedTypes.addAll(ImportResolver.findPrefixedTypeReferences(type));
        // Update typePrefixMap for this field
        typePrefixMap.addAll(ImportResolver.extractTypePrefixMap(type));
        if (fieldDoc != null && fieldDoc.isNotEmpty) {
          buffer.writeln('  /** ${fieldDoc.replaceAll('\n', ' ')} */');
        }
        buffer.writeln('  ${v.name.lexeme}: ${type.toTsType};');
      }
    }
    buffer.writeln('}');
    models.add(ModelInterface(node.name.lexeme, buffer.toString(), docComment: classDoc));
  }

  List<String> getTsImports() {
    final imports = <String>{};
    for (final type in referencedTypes) {
      // Find the prefix for this type (assume _iX.TypeName)
      final prefix = _findPrefixForType(type);
      if (prefix != null && importPrefixes.containsKey(prefix)) {
        final dartImportPath = importPrefixes[prefix]!;
        final tsPath = ImportResolver.mapDartImportToTsPath(dartImportPath, type);
        imports.add(ImportResolver.generateTsImport(type, tsPath));
      }
    }
    return imports.toList();
  }

  String? _findPrefixForType(String type) {
    return typePrefixMap[type];
  }

  // All other visit methods are no-ops
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
