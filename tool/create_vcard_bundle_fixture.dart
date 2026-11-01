import 'dart:io';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 1) {
    stderr.writeln('Usage: create_vcard_bundle_fixture <file>');
    exitCode = 64;
    return;
  }
  await File(arguments.single).writeAsString(
    'BEGIN:VCARD\nVERSION:3.0\nUID:aot-new-contact\n'
    'FN:AOT Secret Contact\nTEL:+15550102000\n'
    'EMAIL:aot-private@example.test\nEND:VCARD\n'
    'BEGIN:VCARD\nVERSION:3.0\nUID:aot-stable-test\n'
    'FN:Also Private\nEND:VCARD\n',
  );
}
