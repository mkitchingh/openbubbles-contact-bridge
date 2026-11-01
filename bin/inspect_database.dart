import 'dart:convert';
import 'dart:io';

import 'package:openbubbles_contact_bridge/src/database_inspector.dart';

Future<void> main(List<String> arguments) async {
  String? snapshot;
  String? output;
  for (var i = 0; i < arguments.length; i++) {
    if (arguments[i] == '--snapshot' && i + 1 < arguments.length) {
      snapshot = arguments[++i];
    } else if (arguments[i] == '--output' && i + 1 < arguments.length) {
      output = arguments[++i];
    } else {
      stderr.writeln('Unknown or incomplete argument: ${arguments[i]}');
      exitCode = 64;
      return;
    }
  }
  if (snapshot == null || output == null) {
    stderr.writeln('Usage: inspect_database --snapshot <directory> --output <json>');
    exitCode = 64;
    return;
  }
  try {
    final report = await inspectSnapshot(Directory(snapshot));
    const encoder = JsonEncoder.withIndent('  ');
    await File(output).writeAsString('${encoder.convert(report)}\n', flush: true);
    stdout.writeln('Wrote redacted inspection report: $output');
  } catch (error) {
    stderr.writeln('Inspection failed: $error');
    exitCode = 1;
  }
}

