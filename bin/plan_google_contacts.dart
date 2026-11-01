import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:openbubbles_contact_bridge/src/carddav_client.dart';
import 'package:openbubbles_contact_bridge/src/dry_run_planner.dart';
import 'package:openbubbles_contact_bridge/src/google_oauth.dart';
import 'package:openbubbles_contact_bridge/src/vcard_parser.dart';

Future<void> main(List<String> arguments) async {
  final options = _parseArguments(arguments);
  if (options == null) {
    exitCode = 64;
    return;
  }
  try {
    final source = options.vcardDirectory == null
        ? options.vcardFile == null
            ? await _fetchGoogle(options.oauthConfig!)
            : await _readVCardFile(options.vcardFile!)
        : await _readFixtureVcards(options.vcardDirectory!);
    final report = await planDryRun(Directory(options.snapshot), source);
    const encoder = JsonEncoder.withIndent('  ');
    await File(options.output)
        .writeAsString('${encoder.convert(report)}\n', flush: true);
    stdout.writeln('Dry run completed. No database writes were performed.');
    stdout.writeln('Wrote count-only report: ${options.output}');
  } catch (error) {
    stderr.writeln('Dry run failed: ${_safeError(error)}');
    exitCode = 1;
  }
}

Future<CardDavSourceSummary> _fetchGoogle(String configPath) async {
  final config = await _readOAuthConfig(File(configPath));
  stdout.writeln('Opening the system browser for Google authorization...');
  final accessToken = await GoogleDesktopOAuth(config: config).authorize();
  stdout.writeln('Authorization received. Fetching Google CardDAV contacts...');
  final result = await GoogleCardDavClient(accessToken: accessToken).fetchAll();
  return CardDavSourceSummary(
    addressBookCount: result.addressBookCount,
    vcardCount: result.vcardCount,
    contacts: result.contacts,
  );
}

Future<GoogleOAuthClientConfig> _readOAuthConfig(File file) async {
  try {
    return GoogleOAuthClientConfig.fromJson(
        jsonDecode(await file.readAsString()));
  } on FormatException {
    throw StateError('The selected OAuth client JSON is invalid.');
  }
}

Future<CardDavSourceSummary> _readFixtureVcards(String directoryPath) async {
  final directory = Directory(directoryPath);
  if (!directory.existsSync()) {
    throw StateError('The vCard fixture directory does not exist.');
  }
  final files = directory
      .listSync()
      .whereType<File>()
      .where((file) => file.path.toLowerCase().endsWith('.vcf'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  final contacts = <FetchedContact>[];
  for (var index = 0; index < files.length; index++) {
    contacts.add(parseVCard(
      await files[index].readAsString(),
      Uri.parse('https://fixture.invalid/card/$index.vcf'),
    ));
  }
  return CardDavSourceSummary(
    addressBookCount: files.isEmpty ? 0 : 1,
    vcardCount: files.length,
    contacts: contacts,
  );
}

Future<CardDavSourceSummary> _readVCardFile(String filePath) async {
  final file = File(filePath);
  if (!file.existsSync()) {
    throw StateError('The selected vCard file does not exist.');
  }
  List<FetchedContact> contacts;
  try {
    contacts = parseVCardBundle(
      await file.readAsString(),
      Uri.parse('https://local-export.invalid/openbubbles/'),
    );
  } on FormatException {
    throw StateError('The selected file contains no valid vCards.');
  }
  return CardDavSourceSummary(
    addressBookCount: 1,
    vcardCount: contacts.length,
    contacts: contacts,
  );
}

String _safeError(Object error) {
  if (error is StateError) return error.message;
  if (error is TimeoutException) return error.message ?? 'Operation timed out.';
  if (error is FileSystemException) return error.message;
  if (error is SocketException) return 'A network connection failed.';
  return 'An unexpected error occurred. No database writes were performed.';
}

_Options? _parseArguments(List<String> arguments) {
  String? snapshot;
  String? output;
  String? oauthConfig;
  String? vcardDirectory;
  String? vcardFile;
  for (var index = 0; index < arguments.length; index++) {
    final option = arguments[index];
    if (index + 1 >= arguments.length) {
      stderr.writeln('Incomplete argument: $option');
      return null;
    }
    final value = arguments[++index];
    switch (option) {
      case '--snapshot':
        snapshot = value;
        break;
      case '--output':
        output = value;
        break;
      case '--oauth-config':
        oauthConfig = value;
        break;
      case '--vcard-directory':
        vcardDirectory = value;
        break;
      case '--vcard-file':
        vcardFile = value;
        break;
      default:
        stderr.writeln('Unknown argument: $option');
        return null;
    }
  }
  if (snapshot == null || output == null) {
    stderr.writeln('Required: --snapshot <directory> --output <json>');
    return null;
  }
  final sources = <String?>[oauthConfig, vcardDirectory, vcardFile]
      .where((value) => value != null)
      .length;
  if (sources != 1) {
    stderr.writeln(
        'Choose exactly one source: --oauth-config, --vcard-file, or --vcard-directory');
    return null;
  }
  return _Options(
    snapshot: snapshot,
    output: output,
    oauthConfig: oauthConfig,
    vcardDirectory: vcardDirectory,
    vcardFile: vcardFile,
  );
}

class _Options {
  const _Options({
    required this.snapshot,
    required this.output,
    required this.oauthConfig,
    required this.vcardDirectory,
    required this.vcardFile,
  });
  final String snapshot;
  final String output;
  final String? oauthConfig;
  final String? vcardDirectory;
  final String? vcardFile;
}
