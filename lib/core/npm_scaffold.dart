import 'dart:io';

import '../utils/constants.dart';

void writeNpmScaffold({
  required String outputPath,
  required String packageName,
  required bool isTs,
}) {
  final packageJson = StringBuffer()
    ..writeln('{')
    ..writeln('  "name": "$packageName",')
    ..writeln('  "version": "$packageVersion",')
    ..writeln('  "description": "Generated Serverpod client for $packageName",')
    ..writeln('  "main": "${isTs ? 'dist/client.js' : 'client.js'}",')
    ..writeln('  "types": "${isTs ? 'dist/client.d.ts' : ''}",')
    ..writeln('  "scripts": {')
    ..writeln(
      '''    "build": "${isTs ? 'tsc' : 'echo \\"No build needed\\"'}",''',
    )
    ..writeln(
      '    "lint": "${isTs ? 'eslint . --ext .ts' : 'eslint . --ext .js'}",',
    )
    ..writeln('    "test": "echo \\"No tests yet\\""')
    ..writeln('  },')
    ..writeln('  "keywords": ["serverpod", "client", "api", "generated"],')
    ..writeln('  "author": "",')
    ..writeln('  "license": "MIT",')
    ..writeln('  "dependencies": {},')
    ..writeln('  "devDependencies": {')
    ..writeln(
      isTs
          ? '''    "typescript": "$typescriptVersion",
    "@typescript-eslint/eslint-plugin": "$typeScriptEslintVersion",
    "@typescript-eslint/parser": "$typeScriptEslintVersion"'''
          : '''    "eslint": "$eslintVersion"''',
    )
    ..writeln('  }')
    ..writeln('}');
  File(
    packageJsonPath.replaceAll('{outputPath}', outputPath),
  ).writeAsStringSync(packageJson.toString());

  // tsconfig.json
  if (isTs) {
    File(
      tsconfigJsonPath.replaceAll('{outputPath}', outputPath),
    ).writeAsStringSync(tsconfigJson);
  }

  // .eslintrc.json
  if (isTs) {
    File(
      eslintrcJsPath.replaceAll('{outputPath}', outputPath),
    ).writeAsStringSync(eslintrcJsTs);
  } else {
    File(
      eslintrcJsonPath.replaceAll('{outputPath}', outputPath),
    ).writeAsStringSync(eslintrcJsonJs);
  }

  // README.md
  File(
    readmePath.replaceAll('{outputPath}', outputPath),
  ).writeAsStringSync(readmeTemplate.replaceAll('{packageName}', packageName));

  // .gitignore
  File(
    gitignorePath.replaceAll('{outputPath}', outputPath),
  ).writeAsStringSync(gitignoreTemplate);

  // index.ts (for easy import)
  if (isTs) {
    File(
      indexTsPath.replaceAll('{outputPath}', outputPath),
    ).writeAsStringSync(indexTsTemplate);
  }
}
