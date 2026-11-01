import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:openbubbles_contact_bridge/src/database_inspector.dart';
import 'package:openbubbles_contact_bridge/src/openbubbles_objectbox.g.dart';
import 'package:openbubbles_contact_bridge/src/openbubbles_objectbox_models.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 1) {
    stderr.writeln('Usage: create_inspection_fixture <directory>');
    exitCode = 64;
    return;
  }

  final root = Directory(arguments.single)..createSync(recursive: true);
  final database = Directory('${root.path}${Platform.pathSeparator}objectbox')
    ..createSync(recursive: true);

  final store = Store(getObjectBoxModel(), directory: database.path);
  try {
    final contactBox = store.box<Contact>();
    final brokenContactId = contactBox.put(Contact(
      id: '',
      displayName: 'AOT Secret Contact',
      phones: const <String>['+15550102000'],
      emails: const <String>['aot-private@example.test'],
    ));
    contactBox.put(Contact(
      id: 'carddav-uid:aot-stable-test',
      displayName: 'AOT Second Secret',
      phones: const <String>[],
      emails: const <String>[],
    ));

    final linkedHandle = Handle(
      originalROWID: 1,
      address: '+15550102000',
      uniqueAddressAndService: '+15550102000/iMessage',
      service: 'iMessage',
    );
    linkedHandle.contactRelation.targetId = brokenContactId;
    store.box<Handle>().put(linkedHandle);
  } finally {
    store.close();
  }

  final dataFile = File('${database.path}${Platform.pathSeparator}data.mdb');
  final dataHash = (await sha256.bind(dataFile.openRead()).first).toString();
  await File('${root.path}${Platform.pathSeparator}$inspectionMarkerName')
      .writeAsString(jsonEncode(<String, Object?>{
    'markerVersion': 1,
    'databaseRelativeDirectory': 'objectbox',
    'dataSha256': dataHash,
    'packageVersion': 'aot-fixture',
  }));
}
