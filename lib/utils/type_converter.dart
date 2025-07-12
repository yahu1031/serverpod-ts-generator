// TypeScript type conversion logic extracted from converter.dart

class TypeConverter {
  static const Map<String, String> _primitiveTypeMap = {
    'int': 'number',
    'double': 'number',
    'num': 'number',
    'String': 'string',
    'bool': 'boolean',
    'dynamic': 'any',
    'Object': 'any',
    'void': 'void',
    'Null': 'null',
    'DateTime': 'Date',
  };

  static const Map<String, String> _collectionTypeMap = {
    'List': 'Array',
    'Set': 'Set',
    'Map': 'Map',
    'Iterable': 'Iterable',
    'Stream': 'AsyncGenerator',
    'Future': 'Promise',
    'Record': 'Record',
  };

  static TsTypeData toTsType(String dartTypeString) {
    return _convertTypeString(dartTypeString);
  }

  static TsTypeData _convertTypeString(String dartTypeString) {
    bool isNullable = dartTypeString.endsWith('?');
    String originalType = dartTypeString;
    if (isNullable) {
      dartTypeString = dartTypeString.substring(0, dartTypeString.length - 1);
    }
    if (dartTypeString.startsWith('(') && dartTypeString.endsWith(')')) {
      return _convertRecordType(dartTypeString, isNullable);
    }
    if (dartTypeString.contains('<')) {
      return _convertGenericType(dartTypeString, isNullable);
    }
    String tsType = _primitiveTypeMap[dartTypeString] ?? dartTypeString;
    return TsTypeData(
      dartType: originalType,
      tsType: isNullable ? '$tsType | null' : tsType,
      isNullable: isNullable,
      genericParams: [],
    );
  }

  static TsTypeData _convertGenericType(String dartTypeString, bool isNullable) {
    int angleStart = dartTypeString.indexOf('<');
    String baseType = dartTypeString.substring(0, angleStart).split('.').last;
    String genericPart = dartTypeString.substring(
      angleStart + 1,
      dartTypeString.lastIndexOf('>'),
    );
    String tsBaseType = _collectionTypeMap[baseType] ?? baseType;
    List<String> genericParamsRaw =
        genericPart.contains('(') && genericPart.contains(')')
        ? [_convertRecordType(genericPart, isNullable).tsType]
        : _parseGenericParameters(genericPart, isNullable);
    List<TsTypeData> convertedParams = genericParamsRaw
        .map((param) => _convertTypeString(param.trim()))
        .toList();
    List<String> convertedParamsStr = convertedParams.map((e) => e.tsType).toList();
    String result;
    switch (baseType) {
      case 'List':
      case 'Set':
        if (convertedParamsStr.length == 1) {
          result = '${convertedParamsStr[0]}[]';
        } else {
          result = '$tsBaseType<${convertedParamsStr.join(', ')}>';
        }
        break;
      case 'Map':
        if (convertedParamsStr.length == 2) {
          result = 'Map<${convertedParamsStr[0]}, ${convertedParamsStr[1]}>';
        } else {
          result = '$tsBaseType<${convertedParamsStr.join(', ')}>';
        }
        break;
      case 'Future':
        result = 'Promise<${convertedParamsStr.join(', ')}>';
        break;
      case 'Stream':
        result = 'AsyncGenerator<${convertedParamsStr.join(', ')}>';
        break;
      case 'Record':
        if (convertedParamsStr.length == 1) {
          result = '[${convertedParamsStr[0]}]';
        } else {
          result = '[${convertedParamsStr.join(', ')}]';
        }
        break;
      default:
        result = '$tsBaseType<${convertedParamsStr.join(', ')}>';
    }
    return TsTypeData(
      dartType: dartTypeString,
      tsType: isNullable ? '$result | null' : result,
      isNullable: isNullable,
      genericParams: convertedParamsStr,
    );
  }

  static TsTypeData _convertRecordType(String recordTypeString, bool isNullable) {
    String content = recordTypeString.startsWith('(') && recordTypeString.endsWith(')')
        ? recordTypeString.substring(1, recordTypeString.length - 1)
        : recordTypeString;
    bool hasNamedFields = content.contains(':') && !content.contains('<');
    bool hasCurlyBraces = content.contains('{') && content.contains('}');
    if (hasCurlyBraces) {
      return _convertMixedRecordType(content, isNullable);
    } else if (hasNamedFields) {
      return _convertNamedRecordType(content, isNullable);
    } else {
      return _convertPositionalRecordType(content, isNullable);
    }
  }

  static TsTypeData _convertNamedRecordType(String content, bool isNullable) {
    List<String> fields = _parseRecordFields(content);
    List<TsTypeData> tsFields = [];
    for (String field in fields) {
      if (field.contains(':')) {
        List<String> parts = field.split(':');
        if (parts.length == 2) {
          String fieldName = parts[0].trim();
          String fieldType = parts[1].trim();
          TsTypeData tsFieldType = _convertTypeString(fieldType);
          if (fieldName.endsWith('?')) {
            fieldName = fieldName.substring(0, fieldName.length - 1);
            tsFields.add(TsTypeData(
              dartType: fieldType,
              tsType: '$fieldName?: ${tsFieldType.tsType}',
              isNullable: true,
              genericParams: [],
            ));
          } else {
            tsFields.add(TsTypeData(
              dartType: fieldType,
              tsType: '$fieldName: ${tsFieldType.tsType}',
              isNullable: false,
              genericParams: [],
            ));
          }
        }
      }
    }
    String result = '{ ${tsFields.map((f) => f.tsType).join(', ')} }';
    return TsTypeData(
      dartType: content,
      tsType: isNullable ? '$result | null' : result,
      isNullable: isNullable,
      genericParams: tsFields.map((f) => f.tsType).toList(),
    );
  }

  static TsTypeData _convertPositionalRecordType(String content, bool isNullable) {
    List<String> fields = _parseRecordFields(content);
    List<TsTypeData> tsFields = fields
        .map((field) => _convertTypeString(field.trim()))
        .toList();
    String result = '[${tsFields.map((f) => f.tsType).join(', ')}]';
    return TsTypeData(
      dartType: content,
      tsType: isNullable ? '$result | null' : result,
      isNullable: isNullable,
      genericParams: tsFields.map((f) => f.tsType).toList(),
    );
  }

  static TsTypeData _convertMixedRecordType(String content, bool isNullable) {
    int curlyStart = content.indexOf('{');
    int curlyEnd = content.lastIndexOf('}');
    if (curlyStart == -1 || curlyEnd == -1) {
      return _convertPositionalRecordType(content, isNullable);
    }
    String positionalPart = content.substring(0, curlyStart).trim();
    if (positionalPart.endsWith(',')) {
      positionalPart = positionalPart
          .substring(0, positionalPart.length - 1)
          .trim();
    }
    String namedPart = content.substring(curlyStart + 1, curlyEnd).trim();
    List<TsTypeData> allTupleElements = [];
    if (positionalPart.isNotEmpty) {
      List<String> positionalFields = _parseRecordFields(positionalPart);
      for (String field in positionalFields) {
        TsTypeData tsFieldType = _convertTypeString(field.trim());
        allTupleElements.add(tsFieldType);
      }
    }
    if (namedPart.isNotEmpty) {
      List<String> namedFields = _parseRecordFields(namedPart);
      List<TsTypeData> tsNamedFields = [];
      for (String field in namedFields) {
        field = field.trim();
        int lastSpaceIndex = -1;
        int angleLevel = 0;
        int parenLevel = 0;
        for (int i = field.length - 1; i >= 0; i--) {
          String currentChar = field[i];
          switch (currentChar) {
            case '>':
              angleLevel++;
              break;
            case '<':
              angleLevel--;
              break;
            case ')':
              parenLevel++;
              break;
            case '(': 
              parenLevel--;
              break;
            case ' ':
              if (angleLevel == 0 && parenLevel == 0) {
                lastSpaceIndex = i;
                break;
              }
              break;
          }
          if (lastSpaceIndex != -1) break;
        }
        if (lastSpaceIndex != -1) {
          String fieldType = field.substring(0, lastSpaceIndex).trim();
          String fieldName = field.substring(lastSpaceIndex + 1).trim();
          TsTypeData tsFieldType = _convertTypeString(fieldType);
          if (fieldName.endsWith('?')) {
            fieldName = fieldName.substring(0, fieldName.length - 1);
            tsNamedFields.add(TsTypeData(
              dartType: fieldType,
              tsType: '$fieldName?: ${tsFieldType.tsType}',
              isNullable: true,
              genericParams: [],
            ));
          } else {
            tsNamedFields.add(TsTypeData(
              dartType: fieldType,
              tsType: '$fieldName: ${tsFieldType.tsType}',
              isNullable: false,
              genericParams: [],
            ));
          }
        }
      }
      if (tsNamedFields.isNotEmpty) {
        allTupleElements.add(TsTypeData(
          dartType: namedPart,
          tsType: '{ ${tsNamedFields.map((f) => f.tsType).join(', ')} }',
          isNullable: false,
          genericParams: tsNamedFields.map((f) => f.tsType).toList(),
        ));
      }
    }
    String result = '[${allTupleElements.map((f) => f.tsType).join(', ')}]';
    return TsTypeData(
      dartType: content,
      tsType: isNullable ? '$result | null' : result,
      isNullable: isNullable,
      genericParams: allTupleElements.map((f) => f.tsType).toList(),
    );
  }

  static List<String> _parseRecordFields(String content) {
    List<String> fields = [];
    int level = 0;
    int start = 0;
    bool inString = false;
    for (int i = 0; i < content.length; i++) {
      var currentChar = content[i];
      if (currentChar == '"' || currentChar == "'") {
        inString = !inString;
      }
      if (!inString) {
        switch (currentChar) {
          case '<':
          case '(':
            level++;
            break;
          case '>':
          case ')':
            level--;
            break;
          case ',':
            if (level == 0) {
              fields.add(content.substring(start, i).trim());
              start = i + 1;
            }
            break;
        }
      }
    }
    if (start < content.length) {
      fields.add(content.substring(start).trim());
    }
    return fields;
  }

  static List<String> _parseGenericParameters(
    String genericPart,
    bool isNullable,
  ) {
    List<String> params = [];
    int level = 0;
    int start = 0;
    for (int i = 0; i < genericPart.length; i++) {
      switch (genericPart[i]) {
        case '<':
          level++;
          break;
        case '>':
          level--;
          break;
        case ',':
          if (level == 0) {
            params.add(genericPart.substring(start, i).trim());
            start = i + 1;
          }
          break;
      }
    }
    if (start < genericPart.length) {
      params.add(genericPart.substring(start).trim());
    }
    return params;
  }
}

class TsTypeData {
  final String dartType;
  final String tsType;
  final bool isNullable;
  final List<String> genericParams;

  TsTypeData({
    required this.dartType,
    required this.tsType,
    required this.isNullable,
    required this.genericParams,
  });

  String get tsTypeString => tsType;

  @override
  String toString() => tsType;
}
