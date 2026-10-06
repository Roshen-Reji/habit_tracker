import 'dart:io';

void main() {
  final libDir = Directory('lib');
  if (!libDir.existsSync()) {
    stderr.writeln('lib directory not found.');
    exit(1);
  }

  int failed = 0;
  final dartFiles = libDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));

  final emptyParenRegex = RegExp(r"' \(\)'|\(Text\(' \(\)'\)");
  final debugPrintEmptyRegex = RegExp(r'''debugPrint\(.*:\s*['"]\s*\)''');
  final sourceRefTrailingUnderscore =
      RegExp(r'''sourceRef:\s*['"][a-zA-Z0-9_]+_['"]''');
  final textPunctuationOnlyRegex =
      RegExp(r'''Text\(\s*['"][ \u00B7():\-_/]+['"]\s*[,)]''');

  for (final file in dartFiles) {
    final lines = file.readAsLinesSync();
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lineNum = i + 1;

      if (emptyParenRegex.hasMatch(line)) {
        stderr.writeln(
            '${file.path}:$lineNum: Found stripped empty parentheses: $line');
        failed = 1;
      }
      if (debugPrintEmptyRegex.hasMatch(line)) {
        stderr.writeln(
            '${file.path}:$lineNum: Found debugPrint with stripped variable: $line');
        failed = 1;
      }
      if (sourceRefTrailingUnderscore.hasMatch(line)) {
        stderr.writeln(
            '${file.path}:$lineNum: Found sourceRef with trailing underscore missing ID: $line');
        failed = 1;
      }
      if (textPunctuationOnlyRegex.hasMatch(line)) {
        stderr.writeln(
            '${file.path}:$lineNum: Found Text() widget with only punctuation/spaces: $line');
        failed = 1;
      }
    }
  }

  if (failed != 0) {
    stderr.writeln('FAIL: String corruption check failed.');
    exit(1);
  } else {
    stdout.writeln('SUCCESS: All string checks passed.');
    exit(0);
  }
}
