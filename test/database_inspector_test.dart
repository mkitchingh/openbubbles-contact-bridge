import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:openbubbles_contact_bridge/src/database_inspector.dart';
import 'package:openbubbles_contact_bridge/src/openbubbles_objectbox.g.dart';
import 'package:openbubbles_contact_bridge/src/openbubbles_objectbox_models.dart';
import 'package:test/test.dart';

void main() {
  test('inspects a marked snapshot without exposing values', () async {
    final root = await Directory.systemTemp.createTemp('ob-bridge-inspector-');
    addTearDown(() => root.delete(recursive: true));
    final database = Directory('${root.path}${Platform.pathSeparator}objectbox')
      ..createSync(recursive: true);

    final store = Store(getObjectBoxModel(), directory: database.path);
    final contactBox = store.box<Contact>();
    final firstId = contactBox.put(Contact(
      id: '',
      displayName: 'Must Not Leak',
      phones: const ['+15550102000'],
      emails: const ['private@example.test'],
    ));
    contactBox.put(Contact(
      id: 'carddav-uid:stable-test',
      displayName: 'Also Private',
      phones: const <String>[],
      emails: const <String>[],
    ));
    final handle = Handle(
      originalROWID: 1,
      address: '+15550102000',
      uniqueAddressAndService: '+15550102000/iMessage',
      service: 'iMessage',
    );
    handle.contactRelation.targetId = firstId;
    store.box<Handle>().put(handle);
    store.close();

    final dataFile = File('${database.path}${Platform.pathSeparator}data.mdb');
    final hash = (await sha256.bind(dataFile.openRead()).first).toString();
    await File('${root.path}${Platform.pathSeparator}$inspectionMarkerName')
        .writeAsString(jsonEncode(<String, Object?>{
      'markerVersion': 1,
      'databaseRelativeDirectory': 'objectbox',
      'dataSha256': hash,
      'packageVersion': 'fixture',
    }));

    final report = await inspectSnapshot(root);
    expect((report['entities'] as Map<String, int>)['contacts'], 2);
    expect((report['contacts'] as Map<String, int>)['emptyIds'], 1);
    expect((report['handles'] as Map<String, int>)['linked'], 1);
    final encoded = jsonEncode(report);
    expect(encoded, isNot(contains('Must Not Leak')));
    expect(encoded, isNot(contains('private@example.test')));
    expect(encoded, isNot(contains('+15550102000')));
  });

  test('refuses an unmarked database', () async {
    final root = await Directory.systemTemp.createTemp('ob-bridge-unmarked-');
    addTearDown(() => root.delete(recursive: true));
    expect(() => inspectSnapshot(root), throwsStateError);
  });
}

