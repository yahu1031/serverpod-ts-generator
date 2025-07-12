import 'dart:io';

import 'package:args/args.dart';
import 'package:serverpod_ts_gen/serverpod_ts_gen.dart' as serverpod_ts_gen;

void main(List<String> arguments) {
  // sampleDartTypesParsing();
  // return;
  final parser = ArgParser()
    ..addOption('input', abbr: 'i', help: 'Path to the Dart client package')
    ..addOption('output', abbr: 'o', help: 'Output directory for TS/JS client')
    ..addOption(
      'target',
      abbr: 't',
      help:
          'Target language for the generated client (typescript or javascript)',
    )
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show help');

  final argResults = parser.parse(arguments);

  if (argResults['help'] as bool ||
      argResults['input'] == null ||
      argResults['output'] == null) {
    print('Serverpod Dart-to-TypeScript/JavaScript Client Generator');
    print(parser.usage);
    exit(0);
  }

  final inputPath = argResults['input'] as String;
  final outputPath = argResults['output'] as String;

  // Get target language from args or prompt user
  final targetLanguage = 'typescript';
  // argResults['target'] as String? ??
  // (() {
  //   final langIndex = Select(
  //     prompt: 'Select the target language for the generated client',
  //     options: ['TypeScript', 'JavaScript'],
  //     initialIndex: 0,
  //   ).interact();
  //   return langIndex == 0 ? 'typescript' : 'javascript';
  // })();

  print('Input Dart client: $inputPath');
  print('Output TS/JS client: $outputPath');
  print('Target language: $targetLanguage');

  // Call main generator logic
  serverpod_ts_gen.generate(
    inputPath: inputPath,
    outputPath: outputPath,
    targetLanguage: targetLanguage,
  );
}
