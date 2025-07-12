// Static string templates and constants for code generation

const protocolPath = '{inputPath}/lib/src/protocol/protocol.dart';
const clientInputPath = '{inputPath}/lib/src/protocol/client.dart';
const protocolDirPath = '{inputPath}/lib/src/protocol';
const modelsDirPath = '{outputPath}/src/models';
const endpointsDirPath = '{outputPath}/src/endpoints';
const clientOutputPath = '{outputPath}/src/client.{ext}';
const packageJsonPath = '{outputPath}/package.json';
const tsconfigJsonPath = '{outputPath}/tsconfig.json';
const eslintrcJsonPath = '{outputPath}/.eslintrc.json';
const eslintrcJsPath = '{outputPath}/eslint.config.mjs';
const readmePath = '{outputPath}/README.md';
const gitignorePath = '{outputPath}/.gitignore';
const indexTsPath = '{outputPath}/src/index.ts';

const errorInvalidClientPackage =
    'Error: The provided path ({inputPath}) does not contain a valid Serverpod client package.\n'
    'Required files protocol.dart and client.dart were not found.\n'
    'Please provide the path to a generated Serverpod client package.';

const errorProtocolDirMissing =
    'Error: Directory {inputPath}/lib/src/protocol does not exist.';

const errorNoDartFiles =
    'Error: No Dart files found in {inputPath}/lib/src/protocol.';

const generatedNotice =
    'Generated models/, endpoints/, and client.ts in {outputPath}';

const packageVersion = '1.0.0';

const typescriptVersion = '^5.8.3';
const eslintVersion = '^9.31.0';
const typeScriptEslintVersion = '^8.36.0';

const tsconfigJson = '''{
  "compilerOptions": {
    "target": "ES2020",
    "module": "CommonJS",
    "declaration": true,
    "outDir": "dist",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true
  },
  "include": ["src"],
  "exclude": ["node_modules"]
}
''';

const eslintrcJsonTs = '''{
  "env": {
    "es2021": true,
    "node": true
  },
  "extends": [
    "eslint:recommended",
    "plugin:@typescript-eslint/recommended"
  ],
  "parserOptions": {
    "ecmaVersion": 12,
    "sourceType": "module"
  },
  "parser": "@typescript-eslint/parser"
}
''';

const eslintrcJsTs = '''import { FlatCompat } from "@eslint/eslintrc";
import js from "@eslint/js";
import tsParser from "@typescript-eslint/parser";
import { defineConfig } from "eslint/config";
import globals from "globals";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const compat = new FlatCompat({
    baseDirectory: __dirname,
    recommendedConfig: js.configs.recommended,
    allConfig: js.configs.all
});

export default defineConfig([{
    extends: compat.extends("eslint:recommended", "plugin:@typescript-eslint/recommended"),

    languageOptions: {
        globals: {
            ...globals.node,
        },

        parser: tsParser,
        ecmaVersion: 12,
        sourceType: "module",
    },
}]);
''';

const eslintrcJsonJs = '''{
  "env": {
    "es2021": true,
    "node": true
  },
  "extends": [
    "eslint:recommended"
  ],
  "parserOptions": {
    "ecmaVersion": 12,
    "sourceType": "module"
  }
}
''';

const readmeTemplate = '''# {packageName}

Generated Serverpod client package.

## Usage

Import the client and use the endpoints:

```ts
import { createApiClient } from './client';
const api = createApiClient('http://localhost:8080');
// api.endpointName.methodName(...)
```
''';

const gitignoreTemplate = '''node_modules/
dist/
''';

const indexTsTemplate = '''export * from './client';
export * from './models';
export * from './endpoints';
''';

const endpointAbstractTemplate =
    '''// Abstract base class for all endpoints - provides common functionality
export abstract class Endpoint {
  protected baseUrl: string;
  
  constructor(baseUrl: string) {
    this.baseUrl = baseUrl;
  }
  
  // Each endpoint must define its name
  abstract get name(): string;
  
  // Common fetch method that can be used by all endpoints
  protected async fetch<T>(path: string, body?: Record<string, unknown>): Promise<T> {
    const response = await fetch(`\${this.baseUrl}\${path}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: body ? JSON.stringify(body) : null,
    });
    
    if (!response.ok) {
      throw new Error(`HTTP error! status: \${response.status}`);
    }
    
    return await response.json();
  }
  
  // Helper method for streaming responses
  protected async *fetchStream<T>(
    path: string, 
    body?: Record<string, unknown>
  ): AsyncGenerator<T, void, unknown> {
    const response = await fetch(`\${this.baseUrl}\${path}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: body ? JSON.stringify(body) : null,
    });

    if (!response.ok) {
      throw new Error(`HTTP error! status: \${response.status}`);
    }

    const reader = response.body?.getReader();
    if (!reader) throw new Error("No readable stream available");

    const decoder = new TextDecoder();
    let buffer = "";

    try {
      while (true) {
        const { value, done } = await reader.read();
        if (done) break;

        buffer += decoder.decode(value, { stream: true });
        const lines = buffer.split("\\n");
        buffer = lines.pop()!; // last element may be partial

        for (const line of lines) {
          if (line.trim()) yield JSON.parse(line) as T;
        }
      }

      // flush decoder & emit final line
      buffer += decoder.decode(); // flush remaining bytes
      if (buffer.trim()) yield JSON.parse(buffer) as T;
    } finally {
      reader.releaseLock();
    }
  }
}
''';
