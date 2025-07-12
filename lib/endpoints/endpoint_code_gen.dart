import '../utils/type_utils.dart';
import 'endpoint_class.dart';

String generateEndpointClassCode(
  EndpointClass endpoint,
  String targetLanguage,
) {
  // Collect all referenced model types from method params and return types
  final referencedTypes = <String>{};
  for (final method in endpoint.methods) {
    final returnType = method.returnType.toTsType;
    final returnTypeString = returnType.tsType;
    final match = RegExp(r'([A-Z][A-Za-z0-9_]+)').allMatches(returnTypeString);
    for (final m in match) {
      referencedTypes.add(m.group(1)!);
    }
    // Params
    for (final param in method.params) {
      final paramType = param.type.toTsType;
      final paramTypeString = paramType.tsType;
      final match = RegExp(r'([A-Z][A-Za-z0-9_]+)').allMatches(paramTypeString);
      for (final m in match) {
        referencedTypes.add(m.group(1)!);
      }
    }
  }
  // Remove endpoint class name itself (avoid self-import)
  referencedTypes.remove(endpoint.name);
  final builtInTypes = {
    'Promise',
    'Date',
    'Record',
    'Set',
    'Map',
    'Array',
    'AsyncGenerator',
    'Iterable',
    'number',
    'string',
    'boolean',
    'void',
    'any',
    'unknown',
    'never',
    'object',
    'symbol',
    'null',
    'undefined',
  };
  final imports = referencedTypes
      .where((type) => !builtInTypes.contains(type))
      .map((type) => "import { $type } from '../models/${type.snakeCase}';")
      .join('\n');

  // Always import the abstract Endpoint base class
  final endpointImport = "import { Endpoint } from './endpoint.abstract';";
  final buffer = StringBuffer();
  buffer.writeln(endpointImport);
  if (imports.isNotEmpty) {
    buffer.writeln(imports);
    buffer.writeln();
  }
  buffer.writeln('export class ${endpoint.name} extends Endpoint {');
  buffer.writeln('  constructor(baseUrl: string) { super(baseUrl); }');
  for (final method in endpoint.methods) {
    final params = method.params
        .map((p) => '${p.name}: ${p.type.toTsType}')
        .join(', ');
    final paramNames = method.params.map((p) => p.name).join(', ');
    final returnType = method.returnType.toTsType;
    final returnTypeString = returnType.tsType;
    final isAsyncIterable = returnTypeString.startsWith('AsyncGenerator<');
    final functionKeyword = 'async';
    if (method.docComment != null && method.docComment!.isNotEmpty) {
      buffer.writeln('  /**');
      for (final line in method.docComment!.split('\n')) {
        buffer.writeln('   * $line');
      }
      buffer.writeln('   */');
    }
    if (method.isGetter == true && method.params.isEmpty) {
      // Generate as a TypeScript getter, not an API call
      buffer.writeln('  get ${method.name}(): $returnTypeString {');
      buffer.writeln('    return ${method.staticValue ?? 'undefined'};');
      buffer.writeln('  }');
    } else {
      if (isAsyncIterable) {
        buffer.writeln('  async *${method.name}($params): $returnTypeString {');
        buffer.writeln(
          '    yield* super.fetchStream<${returnType.genericParams.join(', ')}>(`/${endpoint.name.toLowerCase().replaceAll("endpoint", "")}/${method.name}`${paramNames.isNotEmpty ? ", { $paramNames }" : ''});',
        );
        buffer.writeln('  }');
      } else {
        buffer.writeln(
          '  $functionKeyword ${isAsyncIterable ? '*' : ''}${method.name}($params): $returnTypeString {',
        );
        buffer.writeln(
          '    return await super.fetch<$returnTypeString>(`/${endpoint.name.toLowerCase().replaceAll("endpoint", "")}/${method.name}`${paramNames.isNotEmpty ? ", { $paramNames }" : ''});',
        );
        buffer.writeln('  }');
      }
    }
  }
  buffer.writeln('}');
  return buffer.toString();
}

String generateClientFactoryCode(List<EndpointClass> endpoints) {
  final buffer = StringBuffer();
  buffer.writeln("import * as endpoints from './endpoints/index';");
  buffer.writeln('export function createApiClient(baseUrl: string) {');
  buffer.writeln('  return {');
  for (final endpoint in endpoints) {
    buffer.writeln(
      '    ${endpoint.name.camelCase}: new endpoints.${endpoint.name}(baseUrl),',
    );
  }
  buffer.writeln('  };');
  buffer.writeln('}');
  return buffer.toString();
}
