import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';

import '../endpoints/endpoint_class.dart';
import '../endpoints/endpoint_code_gen.dart';
import '../endpoints/endpoint_collector_visitor.dart';
import '../models/model_interface.dart';
import '../models/model_interface_collector_visitor.dart';
import '../utils/constants.dart';
import '../utils/type_utils.dart';
import 'npm_scaffold.dart';

void generate({
  required String inputPath,
  required String outputPath,
  required String targetLanguage,
}) {
  // Validate that the input path contains a valid Serverpod client package
  final protocolFile = File(protocolPath.replaceAll('{inputPath}', inputPath));
  final clientFile = File(clientInputPath.replaceAll('{inputPath}', inputPath));

  if (!protocolFile.existsSync() || !clientFile.existsSync()) {
    stderr.writeln(
      errorInvalidClientPackage.replaceAll('{inputPath}', inputPath),
    );
    exit(1);
  }

  print('Input Dart client path: $inputPath');
  print('Output TypeScript/JavaScript client path: $outputPath');
  print('Target language: $targetLanguage');

  // Discover all Dart files in lib/src/protocol
  final protocolDir = Directory(
    protocolDirPath.replaceAll('{inputPath}', inputPath),
  );
  if (!protocolDir.existsSync()) {
    stderr.writeln(
      errorProtocolDirMissing.replaceAll('{inputPath}', inputPath),
    );
    exit(1);
  }

  final dartFiles = protocolDir
      .listSync(recursive: false)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  if (dartFiles.isEmpty) {
    stderr.writeln(errorNoDartFiles.replaceAll('{inputPath}', inputPath));
    exit(1);
  }

  print('Found Dart files:');
  for (final file in dartFiles) {
    print('  - ${file.path}');
  }

  // Collect model interfaces and endpoint classes, and track their visitors
  final modelPairs = <(ModelInterface, ModelInterfaceCollectorVisitor)>[];
  final endpointPairs = <(EndpointClass, EndpointCollectorVisitor)>[];

  // Parse each Dart file and collect model interfaces and endpoint classes
  for (final file in dartFiles) {
    final parseResult = parseFile(
      path: file.path,
      featureSet: FeatureSet.latestLanguageVersion(),
    );
    final unit = parseResult.unit;
    final modelVisitor = ModelInterfaceCollectorVisitor();
    unit.visitChildren(modelVisitor);
    for (final model in modelVisitor.models) {
      modelPairs.add((model, modelVisitor));
    }

    final endpointVisitor = EndpointCollectorVisitor();
    unit.visitChildren(endpointVisitor);
    for (final endpoint in endpointVisitor.endpoints) {
      endpointPairs.add((endpoint, endpointVisitor));
    }
  }

  // Write each model interface to its own file in models/
  final modelsDir = Directory(
    modelsDirPath.replaceAll('{outputPath}', outputPath),
  );
  modelsDir.createSync(recursive: true);
  final modelExports = <String>[];
  for (final pair in modelPairs) {
    final model = pair.$1;
    final visitor = pair.$2;
    final fileName =
        '${model.name.snakeCase}.${targetLanguage == 'typescript' ? 'ts' : 'js'}';
    // Get TS imports for this model
    final tsImports = visitor.getTsImports().join('\n');
    // Strip _iX. from type usages in the code
    final code = model.code.replaceAll(RegExp(r'_i\d+\.'), '');
    final file = File('${modelsDir.path}/$fileName');
    // Prepend doc comment if present
    String output = tsImports.isNotEmpty ? '$tsImports\n' : '';
    if (model.docComment != null && model.docComment!.isNotEmpty) {
      output += '/**\n';
      for (final line in model.docComment!.split('\n')) {
        output += ' * $line\n';
      }
      output += ' */\n';
    }
    output += code;
    file.writeAsStringSync(output);
    modelExports.add(
      "export * from './${fileName.replaceAll('.ts', '').replaceAll('.js', '')}';",
    );
  }
  // Write models/index.ts
  File('${modelsDir.path}/index.ts').writeAsStringSync(modelExports.join('\n'));

  // Write each endpoint class to its own file in endpoints/
  final endpointsDir = Directory(
    endpointsDirPath.replaceAll('{outputPath}', outputPath),
  );
  endpointsDir.createSync(recursive: true);
  final endpointExports = <String>[];
  for (final pair in endpointPairs) {
    final endpoint = pair.$1;
    final visitor = pair.$2;
    final fileName =
        '${endpoint.name.snakeCase}.${targetLanguage == 'typescript' ? 'ts' : 'js'}';
    // Get TS imports for this endpoint
    final tsImports = visitor.getTsImports().join('\n');
    // Generate endpoint class code and strip _iX. from type usages
    final code = generateEndpointClassCode(
      endpoint,
      targetLanguage,
    ).replaceAll(RegExp(r'_i\d+\.'), '');
    final file = File('${endpointsDir.path}/$fileName');
    file.writeAsStringSync('$tsImports\n$code');
    endpointExports.add(
      "export * from './${fileName.replaceAll('.ts', '').replaceAll('.js', '')}';",
    );
  }
  // Write endpoints/index.ts
  File(
    '${endpointsDir.path}/index.ts',
  ).writeAsStringSync(endpointExports.join('\n'));

  // Write endpoint.abstract.ts in endpoints dir using endpointAbstractTemplate
  final endpointAbstractFile = File(
    '${endpointsDir.path}/endpoint.abstract.ts',
  );
  if (!endpointAbstractFile.existsSync()) {
    endpointAbstractFile.writeAsStringSync(endpointAbstractTemplate);
  }

  // Write main API client to client.ts
  final endpointClasses = endpointPairs.map((e) => e.$1).toList();
  final ext = targetLanguage == 'typescript' ? 'ts' : 'js';
  final clientOutFile = File(
    clientOutputPath
        .replaceAll('{outputPath}', outputPath)
        .replaceAll('{ext}', ext),
  );
  clientOutFile.writeAsStringSync(generateClientFactoryCode(endpointClasses));
  print(generatedNotice.replaceAll('{outputPath}', outputPath));

  // Write models/client.ts (Client interface with endpoint imports)
  final clientInterfaceFile = File(
    '${modelsDir.path}/client.${targetLanguage == 'typescript' ? 'ts' : 'js'}',
  );
  final endpointClassNames = endpointClasses.map((e) => e.name).toList();
  final endpointImports = endpointClassNames
      .map((name) => "import { $name } from '../endpoints/${name.snakeCase}';")
      .join('\n');
  final clientInterface = [
    endpointImports,
    '',
    'export interface Client {',
    for (final name in endpointClassNames) '  ${name.camelCase}: $name;',
    '}',
    '',
  ].join('\n');
  clientInterfaceFile.writeAsStringSync(clientInterface);

  // --- NPM PACKAGE SCAFFOLDING ---
  final outDir = Directory(outputPath);
  final packageName = outDir.uri.pathSegments
      .where((s) => s.isNotEmpty)
      .last
      .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '-');
  final isTs = targetLanguage == 'typescript';

  writeNpmScaffold(
    outputPath: outputPath,
    packageName: packageName,
    isTs: isTs,
  );
}
