import 'package:analyzer/dart/ast/ast.dart';

import '../utils/import_resolver.dart';
import 'endpoint_class.dart';
import 'endpoint_method.dart';
import 'endpoint_param.dart';

String? extractDocComment(AnnotatedNode node) {
  final doc = node.documentationComment;
  if (doc == null) return null;
  return doc.tokens.map((t) => t.toString().replaceFirst('///', '').trim()).join('\n');
}

class EndpointCollectorVisitor implements AstVisitor<void> {
  final List<EndpointClass> endpoints = [];
  Map<String, String> importPrefixes = {};
  Set<String> referencedTypes = {};
  Map<String, String> typePrefixMap = {};

  @override
  void visitCompilationUnit(CompilationUnit node) {
    importPrefixes = ImportResolver.parseImportsFromUnit(node);
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    // Heuristic: endpoint classes start with 'Endpoint'
    if (!node.name.lexeme.startsWith('Endpoint')) return;
    final methods = <EndpointMethod>[];
    final methodDecls = node.members.whereType<MethodDeclaration>();
    for (final method in methodDecls) {
      final params = <EndpointParam>[];
      final paramList = method.parameters?.parameters ?? [];
      for (final p in paramList) {
        if (p is SimpleFormalParameter) {
          params.add(
            EndpointParam(p.name?.lexeme ?? '', p.type?.toSource() ?? 'any'),
          );
          referencedTypes.addAll(ImportResolver.findPrefixedTypeReferences(p.type?.toSource() ?? 'any'));
          typePrefixMap.addAll(ImportResolver.extractTypePrefixMap(p.type?.toSource() ?? 'any'));
        } else if (p is DefaultFormalParameter &&
            p.parameter is SimpleFormalParameter) {
          final sp = p.parameter as SimpleFormalParameter;
          params.add(
            EndpointParam(sp.name?.lexeme ?? '', sp.type?.toSource() ?? 'any'),
          );
          referencedTypes.addAll(ImportResolver.findPrefixedTypeReferences(sp.type?.toSource() ?? 'any'));
          typePrefixMap.addAll(ImportResolver.extractTypePrefixMap(sp.type?.toSource() ?? 'any'));
        } else {
          params.add(EndpointParam('unknown', 'any'));
        }
      }
      final returnType = method.returnType?.toSource() ?? 'any';
      referencedTypes.addAll(ImportResolver.findPrefixedTypeReferences(returnType));
      typePrefixMap.addAll(ImportResolver.extractTypePrefixMap(returnType));
      String? staticValue;
      if (method.isGetter) {
        // Try to extract static value from getter body
        if (method.body is ExpressionFunctionBody) {
          final exprBody = method.body as ExpressionFunctionBody;
          staticValue = exprBody.expression.toSource();
        } else if (method.body is BlockFunctionBody) {
          final block = method.body as BlockFunctionBody;
          final returnStmt = block.block.statements.whereType<ReturnStatement>().firstOrNull;
          if (returnStmt != null && returnStmt.expression != null) {
            staticValue = returnStmt.expression!.toSource();
          }
        }
      }
      final docComment = extractDocComment(method);
      methods.add(EndpointMethod(method.name.lexeme, params, returnType, isGetter: method.isGetter, staticValue: staticValue, docComment: docComment));
    }
    endpoints.add(EndpointClass(node.name.lexeme, methods));
  }

  List<String> getTsImports() {
    final imports = <String>{};
    for (final type in referencedTypes) {
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
