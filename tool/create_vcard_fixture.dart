import 'dart:io';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 1) {
    stderr.writeln('Usage: create_vcard_fixture <directory>');
    exitCode = 64;
    return;
  }
  final root = Directory(arguments.single)..createSync(recursive: true);
  await File('${root.path}${Platform.pathSeparator}one.vcf').writeAsString(
    'BEGIN:VCARD\nVERSION:3.0\nUID:aot-new-contact\n'
    'FN:AOT Secret Contact\nTEL:+15550102000\n'
    'EMAIL:aot-private@example.test\nEND:VCARD\n',
  );
  await File('${root.path}${Platform.pathSeparator}two.vcf').writeAsString(
    'BEGIN:VCARD\nVERSION:3.0\nUID:aot-stable-test\n'
    'FN:Also Private\nEND:VCARD\n',
  );
}
