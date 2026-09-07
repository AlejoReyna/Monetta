/// Fails before Flutter starts when a catalog build is missing its authority.
library;

import 'dart:convert';
import 'dart:io';

import 'package:monetta_app/tooling/dart_defines_validation.dart';

void main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln(
      'Uso: dart run bin/validate_dart_defines.dart <archivo.json> <entorno>',
    );
    exitCode = 64;
    return;
  }

  final file = File(args[0]);
  if (!file.existsSync()) {
    stderr.writeln('Falta ${file.path}. Créalo desde el archivo .example.');
    exitCode = 2;
    return;
  }

  late final Map<String, Object?> values;
  try {
    values = Map<String, Object?>.from(
      jsonDecode(file.readAsStringSync()) as Map,
    );
  } catch (error) {
    stderr.writeln('${file.path} no contiene JSON válido: $error');
    exitCode = 2;
    return;
  }

  final expectedEnvironment = args[1];
  final errors = validateDartDefines(
    values: values,
    expectedEnvironment: expectedEnvironment,
  );

  if (errors.isNotEmpty) {
    stderr.writeln('Configuración de catálogo inválida:');
    for (final error in errors) {
      stderr.writeln('  - $error');
    }
    exitCode = 2;
    return;
  }

  stdout.writeln('Configuración $expectedEnvironment válida.');
}
